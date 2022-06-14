package LibreCat::App::Catalogue::Route::publication;

=head1 NAME LibreCat::App::Catalogue::Route::publication

Route handler for publications.

=cut

use Catmandu::Sane;
use Catmandu;
use LibreCat qw(:self publication searcher);
use Catmandu::Fix qw(expand);
use Catmandu::Util qw(is_instance :is);
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::Permission;
use Dancer qw(:syntax);
use Dancer::Plugin::FlashMessage;
use Encode qw(encode);
use File::Spec;
use URI::Escape qw(uri_escape);

sub access_denied_hook {
    h->hook('publication-access-denied')
        ->fix_around({_id => params->{id}, user_id => session->{user_id},});
}

sub decode_file {

    my $file = $_[0];

    $file = [] unless defined $file;

    #a single file was sent
    $file = [ $file ] if is_string( $file );

    #a list of files were sent. Make sure this hook does not break a correct record.file
    $file = [
        map {
            is_string( $_ ) ? from_json( encode("utf8",$_) ) : $_;
        } @$file
    ];

    $file;

}

=head1 PREFIX /librecat/record

All actions related to a publication record are handled under this prefix.

=cut

prefix '/librecat/record' => sub {

=head2 GET /new

Prints a list of available publication types + import form.

Some fields are pre-filled.

=cut

    get '/new' => sub {
        my $params_query= params("query");
        my $h           = h();
        my $type        = $params_query->{type};
        my $user_id     = session("user_id");
        my $user_login  = session("user");
        my $user_role   = session("role");
        my $user        = $h->current_user;

        return template 'backend/add_new' unless $type;

        # Need to generate a new publication identifier to be
        # able to load files associated with this new record...
        my $id = publication->generate_id;

        # set some basic values
        my $data = {
            _id        => $id,
            type       => $type,
            department => $user->{department},
            creator => { id => $user_id, login => $user_login },
            user_id => $user_id,
        };

        # Use config/hooks.yml to register functions
        # that should run before/after adding new publications
        # E.g. create a hooks to change the default fields
        state $hook = $h->hook('publication-new');

        $hook->fix_before($data);

        #-- Fill out default fields ---

        if ( $user_role eq "user") {
            my $person = {
                first_name => $user->{first_name},
                last_name  => $user->{last_name},
                full_name  => $user->{full_name},
                id         => $user_id,
            };
            $person->{orcid} = $user->{orcid} if $user->{orcid};

            if (   $type eq "bookEditor"
                or $type eq "conferenceEditor"
                or $type eq "journalEditor")
            {
                $data->{editor}->[0] = $person;
            }
            elsif ($type eq "translation" or $type eq "translationChapter") {
                $data->{translator}->[0] = $person;
            }
            else {
                $data->{author}->[0] = $person;
            }
        }

        if( $h->locale_exists( $params_query->{lang} ) ){
            $data->{lang} = $params_query->{lang};
        }

        # -- end default fields ---

        $hook->fix_after($data);

        # Important values and flags for the form in order to distinguish between the contexts
        # it is used in
        var form_action => uri_for( "/librecat/record" );
        var form_method => "POST";
        var new_record  => 1;

        my $template = File::Spec->catfile(
            "backend","forms",$type
        );

        template $template, $data;
    };

=head2 GET /edit/:id

Displays record for id.

Checks if the user has permission the see/edit this record.

=cut

    get '/edit/:id' => sub {

        my $id  = params("route")->{id};
        my $rec = publication->get($id) or pass;

        unless (
            p->can_edit(
                $rec->{_id},
                {user_id => session("user_id"), role => session("role")}
            )
            )
        {
            access_denied_hook();
            status '403';
            forward '/access_denied', {referer => request->referer};
        }

        # Use config/hooks.yml to register functions
        # that should run before/after edit publications
        state $hook = h->hook('publication-edit');

        $hook->fix_before($rec);

        my $template = File::Spec->catfile(
            "backend","forms", $rec->{type}
        );

        $rec->{return_url} = request->referer if request->referer;

        # --- End setting edit mode

        $hook->fix_after($rec);

        # Important values and flags for the form in order to distinguish between the contexts
        # it is used in
        var form_action => uri_for(
            "/librecat/record/".uri_escape($id),{ "x-tunneled-method" => "PUT" }
        );
        var form_method => "POST";
        var new_record  => 0;

        template $template, $rec;
    };

=head2 POST /update

Deprecated route: all trafic is internally forwarded to

* C<POST "/librecat/record"> when body parameter C<new_record> is given, or when body parameter C<_id> is missing.

* C<PUT "/librecat/record/:id"> when body parameter C<_id> is given and body parameter C<new_record> is missing.

=cut

    post '/update' => sub {
        my $params_body = params("body");

        if( $params_body->{new_record} ){

            forward "/librecat/record",{},{ method => "POST" };

        }

        if( is_string( $params_body->{_id} ) ){

            forward "/librecat/record/".uri_escape( $params_body->{_id} ),{},{ method => "PUT" };

        }

        forward "/librecat/record",{},{ method => "POST" };

    };

=head2 GET /return/:id

Set status to 'returned'.

Checks if the user has the rights to edit this record.

=cut

    get '/return/:id' => sub {
        my $return_url = params->{return_url};

        my $rec = publication->get(param("id")) or pass;

        unless (
            p->can_return(
                $rec->{_id},
                {user_id => session("user_id"), role => session("role")}
            )
            )
        {
            access_denied_hook();
            status '403';
            forward '/access_denied';
        }

        $rec->{user_id} = session("user_id");

        # Use config/hooks.yml to register functions
        # that should run before/after returning publications
        h->hook('publication-return')->fix_around(
            $rec,
            sub {
                $rec->{status} = "returned";
                publication->add($rec);
            }
        );

        redirect $return_url || uri_for('/librecat');
    };

=head2 GET /delete/:id

Deletes record with id. For admins only.

=cut

    get '/delete/:id' => sub {
        my $id = params->{id};

        my $rec = publication->get($id);

        unless (
            p->can_delete(
                $rec->{_id},
                {user_id => session("user_id"), role => session("role")}
            )
            )
        {
            access_denied_hook();
            status '403';
            forward '/access_denied';
        }

        $rec->{user_id} = session->{user_id};

        # Use config/hooks.yml to register functions
        # that should run before/after deleting publications
        h->hook('publication-delete')->fix_around(
            $rec,
            sub {
                publication->delete($id);
            }
        );

        redirect uri_for('/librecat');
    };

=head2 GET /preview/:id.:fmt

Export publication with ID :id in format :fmt

Only publications with status C<deleted> are not visible.

=cut

get '/preview/:id.:fmt' => sub {
    my $rparams = params("route");
    my $id  = $rparams->{id};
    my $fmt = $rparams->{fmt} // 'yaml';

    forward "/librecat/export", {cql => "id=$id", fmt => $fmt , limit => 1};
};

=head2 GET /preview/id

Prints the frontdoor for every record.

=cut

    get '/preview/:id' => sub {
        my $id = params->{id};

        my $hits = publication->get($id);

        $hits->{style}  = h->default_style;
        $hits->{marked} = 0;

        template 'publication/record.tt', $hits;
    };

=head2 GET /internal_view/:id

Prints internal view, optionally as data dumper.

For admins only!

=cut

    get '/internal_view/:id' => sub {
        my $id = params->{id};

        my $rec; my $hits;
        if(params->{searcher}){
          $rec = publication->search_bag->get($id);
        }
        else {
          $rec = publication->get($id);
        }

        unless ($rec) {
            return template 'error',
                {message => "No publication found with ID $id."};
        }

        my $export_string;
        my $exporter = Catmandu->exporter('YAML', file => \$export_string);
        $exporter->add($rec);

        $export_string = Encode::encode( 'UTF-8', $export_string );

        my %headers = (
            'Content-Type'   => 'text/plain' ,
            'Content-Length' => length($export_string) ,
        );

        Dancer::Response->new(
           status => 200,
           content => $export_string,
           encoded => 1,
           headers => [%headers],
           forward => ""
       );
    };

=head2 GET /clone/:id

Clones the record with ID :id and returns a form with a different ID.

=cut

    get '/clone/:id' => sub {
        my $id  = params("route")->{id};
        my $rec = publication->get($id);

        unless ($rec) {
            return template 'error',
                {message => "No publication found with ID $id."};
        }

        delete $rec->{_version};
        delete $rec->{date_created};
        delete $rec->{date_updated};
        delete $rec->{urn};
        delete $rec->{doi};
        delete $rec->{file};
        delete $rec->{related_material};

        $rec->{_id}     = publication->generate_id;
        $rec->{status}  = "new";
        $rec->{creator} = {id => session("user_id"), login => session("user")};

        #important values and flags for the form in order to distinguish between the contexts
        #it is used in
        var form_action => uri_for( "/librecat/record" );
        var form_method => "POST";
        var new_record  => 1;

        my $template = File::Spec->catfile(
            "backend","forms",$rec->{type}
        );

        template $template, $rec;
    };

=head2 GET /publish/:id

Publishes private records, returns to the list.

=cut

    get '/publish/:id' => sub {
        my $return_url = params->{return_url};

        my $rec = publication->get(param("id")) or pass;

        unless (
            p->can_make_public(
                $rec->{_id},
                {user_id => session("user_id"), role => session("role")}
            )
            )
        {
            access_denied_hook();
            status '403';
            forward '/access_denied';
        }

        my $old_status = $rec->{status};

        if (session->{role} eq "super_admin") {
            $rec->{status} = "public";
        }
        elsif ($rec->{type} eq "research_data") {
            $rec->{status} = "submitted" if $old_status eq "private";
        }
        else {
            $rec->{status} = "public";
        }

        if ($rec->{status} ne $old_status) {

            # Use config/hooks.yml to register functions
            # that should run before/after publishing publications
            state $hook = h->hook('publication-publish');

            $hook->fix_before($rec);

            publication->add($rec);

            $hook->fix_after($rec);
        }

        redirect $return_url || uri_for('/librecat');
    };

=head2 POST /change_type

Changes the type of the publication.

The record is not stored yet.

=cut

    post '/change_type' => sub {
        my $params_body = params("body");
        my $h = h();

        #unpack strange format of record.file
        #TODO: this should not be necessary
        $params_body->{file} = decode_file( $params_body->{file} );

        my $body = $h->nested_params( $params_body );

        # Use config/hooks.yml to register functions
        # that should run before/after changing the edit mode
        state $hook = $h->hook('publication-change-type');
        $hook->fix_before($body);
        $hook->fix_after($body);

        # Important values and flags for the form in order to distinguish between the contexts
        # it is used in
        if( publication()->get( $body->{_id} ) ){

            var form_action => uri_for(
                "/librecat/record/".uri_escape( $body->{_id} ),{ "x-tunneled-method" => "PUT" }
            );
            var form_method => "POST";
            var new_record  => 0;

        }
        else {

            var form_action => uri_for( "/librecat/record" );
            var form_method => "POST";
            var new_record  => 1;

        }

        my $template = File::Spec->catfile(
            "backend","forms",$body->{type}
        );

        template $template, $body;
    };

=head2 POST /

Saves a new record in the database.

=cut

    post "/" => sub {

        my $params_query = params("query");
        my $params_body  = params("body");
        my $request      = request();
        my $return_url   = is_string( $params_body->{return_url} ) ?
            $params_body->{return_url} : $request->uri_for("/librecat");
        delete $params_body->{return_url};
        my $h = h();
        my $librecat = librecat();
        my $model = publication();

        $h->log->debug( "Body parameters:" . to_dumper($params_body) );

        #record should not be present
        if( $model->get( $params_body->{_id} ) ){

            flash danger => $h->localize( "error.record_id_taken", $params_body->{_id} );
            return redirect $return_url;

        }

        # When the form isn't fully loaded when the record is saved bail out and cry for help
        if( $params_body->{_end_} ne "_end_" ){
            flash danger => $h->localize("error.preliminary_submit");
            return redirect $return_url;
        }
        delete $params_body->{_end_};

        # Unpack strange format of record.file
        # TODO: this should not be necessary
        $params_body->{file} = decode_file( $params_body->{file} );

        my $body = $h->nested_params( $params_body );

        # User that last updated this record
        $body->{user_id} = session("user_id");

        # This used to live in the form..
        $body->{status} = "private";

        # Use config/hooks.yml to register functions
        # that should run before/after updating publications
        my @error_messages;

        try {
            $h->hook("publication-create")->fix_around(
                $body,
                sub {
                    $model->add(
                        $body,
                        on_validation_error => sub {
                            my($rec, $errors) = @_;
                            $librecat->log->errorf(
                                "%s not a valid publication %s",
                                $rec->{_id},
                                [map { $_->localize() } @$errors]
                            );
                            my $current_locale = $h->locale();
                            @error_messages  = map {
                                $_->localize( $current_locale );
                            } @$errors;
                        }
                    );
                }
            );
        }
        catch {

            $h->log->fatal("failed to create record");
            $h->log->fatal($_);

            push @error_messages,
                $h->localize( "error.create_failed", $body->{_id} ) . " " .
                $h->localize( "error.contact_admin",$h->config->{admin_email} );

        };

        # All is well
        return redirect $return_url if scalar( @error_messages ) == 0;

        # When we have an error record we return to the edit form and show
        # all errors...
        my $template = File::Spec->catfile(
            "backend","forms", $body->{type}
        );

        flash danger => join( "<br>", @error_messages );

        # Important values and flags for the form in order to distinguish between the contexts
        # it is used in
        var form_action => $request->uri_for( "/librecat/record" );
        var form_method => "POST";
        var new_record  => 1;

        template $template, $body;

    };

=head2 PUT /:id

Updates an existing record in the database

Checks if the user has the rights to update this record.

All data must be supplied

If record does not exist, then this route does not match

=cut

    put "/:id" => sub {

        my $id = params("route")->{id};
        my $params_query = params("query");
        my $params_body  = params("body");
        my $request      = request();
        my $return_url   = is_string( $params_body->{return_url} ) ?
            $params_body->{return_url} : $request->uri_for("/librecat");
        delete $params_body->{return_url};
        my $h       = h();
        my $p       = p();
        my $model   = publication();
        my $librecat = librecat();

        #record not found
        pass unless $model->get( $id );

        $h->log->debug( "Body parameters:" . to_dumper($params_body) );

        # When the form isn't fully loaded when the record is saved bail out and cry for help
        if( $params_body->{_end_} ne "_end_" ){
            flash danger => $h->localize("error.preliminary_submit");
            return redirect $return_url;
        }
        delete $params_body->{_end_};

        # Unpack strange format of record.file
        # TODO: this should not be necessary
        $params_body->{file} = decode_file( $params_body->{file} );

        my $body = $h->nested_params( $params_body );

        # Just to make sure..
        $body->{_id} = $id;

        # User that last updated this record
        $body->{user_id} = session("user_id");

        my $finalSubmit = delete $body->{finalSubmit};
        $finalSubmit    = is_string( $finalSubmit ) ? $finalSubmit : "";

        if(
            $finalSubmit eq "recPublish" &&
            $p->can_make_public(
                $id,
                { user_id => session("user_id"), role => session("role")}
            )
        ){
            # ok
        }
        elsif(
            $finalSubmit eq "recReturn" &&
            $p->can_return(
                $id,
                { user_id => session("user_id"), role => session("role")}
            )
        ){
            # ok
        }
        elsif(
            $finalSubmit eq "recSubmit" && $p->can_submit(
                $id,
                { user_id => session("user_id"), role => session("role")}
            )
        ){
            # ok
        }
        elsif(
            $p->can_edit(
                $id,
                { user_id => session("user_id"), role => session("role")}
            )
        ){
            # ok
        }
        else {
            access_denied_hook();
            status "403";
            forward "/access_denied";
        }

        if( $finalSubmit eq "" ){
            $librecat->log->warn("receiving an empty finalSubmit from the form");
        }
        elsif( $finalSubmit eq "recSubmit" ){
            $body->{status} = "submitted";
        }
        elsif( $finalSubmit eq "recPublish" ){
            $body->{status} = "public";
        }
        elsif( $finalSubmit eq "recReturn" ){
            $body->{status} = "returned";
        }
        else{
            $librecat->log->warnf(
                "receiving an unknown finalSubmit `%s` from the form", $finalSubmit
            );
        }

        # Use config/hooks.yml to register functions
        # that should run before/after updating publications
        my @error_messages;

        try {
            $h->hook("publication-update")->fix_around(
                $body,
                sub {
                    publication->add(
                        $body,
                        on_validation_error => sub {
                            my($rec, $errors) = @_;
                            $librecat->log->errorf(
                                "%s not a valid publication %s",
                                $id,
                                [map { $_->localize() } @$errors]
                            );
                            my $current_locale = $h->locale();
                            @error_messages  = map {
                                $_->localize( $current_locale );
                            } @$errors;
                        }
                    );
                }
            );
        }
        catch {

            if( is_instance($_, "LibreCat::Error::VersionConflict") ){
                flash warning => $h->localize("error.version_conflict");
            }
            else{

                $h->log->fatal("failed to update record $id");
                $h->log->fatal($_);

                push @error_messages,
                    $h->localize( "error.update_failed",$id ) . " " .
                    $h->localize( "error.contact_admin",$h->config->{admin_email} );

            }

        };

        # All is well
        return redirect( $return_url ) if scalar( @error_messages ) == 0;

        # When we have an error record we return to the edit form and show
        # all errors...
        my $template = File::Spec->catfile(
            "backend","forms", $body->{type}
        );

        flash danger => join( "<br>", @error_messages );

        # Important values and flags for the form in order to distinguish between the contexts
        # it is used in
        var form_action => $request->uri_for(
            "/librecat/record/".uri_escape($id),{ "x-tunneled-method" => "PUT" }
        );
        var form_method => "POST";
        var new_record  => 0;

        template $template, $body;

    };

};

1;
