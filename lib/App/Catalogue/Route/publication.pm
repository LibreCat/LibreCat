package App::Catalogue::Route::publication;

=head1 NAME App::Catalogue::Route::publication

    Route handler for publications.

=cut

use Catmandu::Sane;
use App::Helper;
use App::Catalogue::Controller::Publication;
use App::Catalogue::Controller::Permission qw/:can/;
use Dancer ':syntax';
use Try::Tiny;
use Dancer::Plugin::Auth::Tiny;

Dancer::Plugin::Auth::Tiny->extend(
    role => sub {
        my ($role, $coderef) = @_;
          return sub {
            if ( session->{role} && $role eq session->{role} ) {
                goto $coderef;
            }
            else {
                redirect '/access_denied';
            }
          }
        }
);

=head1 PREFIX /record

    All actions related to a publication record are handled under
    this prefix.

=cut

prefix '/myPUB/record' => sub {

=head2 GET /new

    Prints a list of available publication types + import form.
    Some fields are pre-filled.

=cut

    get '/new' => needs login => sub {
        my $type = params->{type};
        my $user = h->getPerson(session->{personNumber});
        my $edit_mode = params->{edit_mode} || $person->{edit_mode} || "";

        return template 'add_new' unless $type;

        my $data;
        my $id = new_publication();
        $data->{_id} = $id;
        $data->{type} = $type;
        $data->{department} = $user->{department};

        if ( $type eq "researchData" ) {
            $data->{doi} = h->config->{doi}->{prefix} . "/" . $id;
        }

        my $templatepath = "backend/forms";

        if(($edit_mode and $edit_mode eq "expert") or (!$edit_mode and session->{role} eq "super_admin")){
        	$templatepath .= "/expert";
        }

        template $templatepath . "/$type", $data;
    };

=head2 GET /edit/:id

    Display record for id.
    Checks if the user has permission the see/edit this record.

=cut

    get '/edit/:id' => needs login => sub {
        my $id = param 'id';

        unless (can_edit($id, session->{user}, session->{role})) {
            status '403';
            forward '/access_denied';
        }
        my $person = h->getPerson(session->{personNumber});
        my $edit_mode = params->{edit_mode} || $person->{edit_mode} || "";

        forward '/' unless $id;
        my $rec;
        try {
            $rec = edit_publication($id);
        }
        catch {
            template 'error', { error => "Something went wrong: $_" };
        };

        my $templatepath = "backend/forms";
        if(($edit_mode and $edit_mode eq "expert") or (!$edit_mode and session->{role} eq "super_admin")){
        	$templatepath .= "/expert";
        }
        if ($rec) {
            template $templatepath . "/$rec->{type}", $rec;
        }
        else {
            template 'error', { error => "No publication with ID $id." };
        }
    };

=head2 POST /update

    Saves the record in the database.
    Checks if the user has the rights to update this record.
    Validation of the record is performed.

=cut

    post '/update' => needs login => sub {
        my $params = params;

        unless (can_edit($params->{_id}, session->{user}, session->{role})) {
            status '403';
            forward '/access_denied';
        }

        foreach my $key ( keys %$params ) {
            if ( ref $params->{$key} eq "ARRAY" ) {
                my $i = 0;
                foreach my $entry ( @{ $params->{$key} } ) {
                    $params->{ $key . "." . $i } = $entry, $i++;
                }
                delete $params->{$key};
            }
        }

        $params = h->nested_params($params);

        if ( ( $params->{department} and $params->{department} eq "" )
            or !$params->{department} )
        {
            $params->{department} = ();
            if ( session->{role} ne "super_admin" ) {
                my $person = h->getPerson( session->{personNumber} );
                foreach my $dep ( @{ $person->{department} } ) {
                    push @{ $params->{department} }, $dep->{id};
                }
            }
        }
        elsif ( $params->{department}
            and $params->{department} ne ""
            and ref $params->{department} ne "ARRAY" )
        {
            $params->{department} = [ $params->{department} ];
        }

        ( session->{role} eq "super_admin" )
            ? ( $params->{approved} = 1 )
            : ( $params->{approved} = 0 );

        unless($params->{creator}){
        	$params->{creator}->{login} = session 'user';
        	$params->{creator}->{id} = session 'personNumber';
        }
#return to_dumper $params;
        my $result = update_publication($params);

        redirect '/myPUB';
    };

=head2 GET /return/:id

    Set status to 'returned'.
    Checks if the user has the rights to return this record.

=cut

    get '/return/:id' => needs login => sub {
        my $id  = params->{id};

        unless (can_edit($id, session->{user}, session->{role})) {
            status '403';
            forward '/access_denied';
        }

        my $rec = h->publication->get($id);
        $rec->{status} = "private";
        try {
            update_publication($rec);
        }
        catch {
            template "error", { error => "something went wrong" };
        };

        redirect '/myPUB';
    };

=head2 GET /delete/:id

    Deletes record with id. For admins only.

=cut

    get '/delete/:id' => needs role => 'super_admin' => sub {
        delete_publication( params->{id} );
        redirect '/myPUB';
    };

=head2 GET /preview/id

    Prints the frontdoor for every record.

=cut

    get '/preview/:id' => needs login => sub {
        my $id   = params->{id};
        my $hits = h->publication->get($id);
        $hits->{bag}
            = $hits->{type} eq "researchData" ? "data" : "publication";
        $hits->{style}
            = h->config->{store}->{default_fd_style} || "frontShort";
        $hits->{marked}  = 0;
        template 'frontdoor/record.tt', $hits;
    };

    get '/publish/:id' => needs login => sub {
        my $id     = params->{id};

        unless (can_edit($id, session->{user}, session->{role})) {
            status '403';
            forward '/access_denied';
        }

        my $record = h->publication->get($id);

        #check if all mandatory fields are filled
        my $publtype;
        if ($record->{type} =~ /^bi[A-Z]/) {
        	$publtype = "bithesis";
        } else {
        	$publtype = lc($record->{type});
        }

        my $basic_fields = h->config->{forms}->{publicationTypes}->{$publtype}->{fields}->{basic_fields};
        my $field_check = 1;

        foreach my $key ( keys %$basic_fields ) {
            next if $key eq "tab_name";
            if($key eq "writer"){
            	my $writer_check = 0;
            	foreach my $label (keys %{$basic_fields->{$key}->{label}}){
            		if($record->{$basic_fields->{$key}->{label}->{$label}} and $record->{$basic_fields->{$key}->{label}->{$label}} ne ""){
            			$writer_check = 1;
            		}
            	}
            	$field_check = 0 if !$writer_check;
            }
            elsif ( $basic_fields->{$key}->{mandatory} and $basic_fields->{$key}->{mandatory} eq "1"
                and ( !$record->{$key} || $record->{$key} eq "" ) )
            {
                $field_check = 0;
            }
        }

        $record->{status} = "public" if $field_check;
        my $result  = h->publication->add($record);
        my $publbag = Catmandu->store->bag('publication');
        $publbag->add($result);
        h->publication->commit;
        redirect '/myPUB';
    };

=head2 GET /change_mode

    Prints the frontdoor for every record.

=cut

    post '/change_mode' => sub {
    	my $mode = params->{edit_mode};
        my $params = params;

        $params->{file} = [$params->{file}] if ($params->{file} and ref $params->{file} ne "ARRAY");
        $params->{file_order} = [$params->{file_order}] if ($params->{file_order} and ref $params->{file_order} ne "ARRAY");

        foreach my $key ( keys %$params ) {
            if ( ref $params->{$key} eq "ARRAY" ) {
            	$params->{$key} = $params->{$key}->[0];
#                my $i = 0;
#                foreach my $entry ( @{ $params->{$key} } ) {
#                    $params->{ $key . "." . $i } = $entry, $i++;
#                }
#                delete $params->{$key};
            }
        }

        $params = h->nested_params($params);
        foreach my $fi (@{$params->{file}}){
        	$fi = from_json($fi);
        	$fi->{file_json} = to_json($fi);
        }

        my $path = "backend/forms/";
        $path .= "expert/" if $mode eq "expert";
        $path .= params->{type} . ".tt";

        template $path, $params;
    };
};

1;
