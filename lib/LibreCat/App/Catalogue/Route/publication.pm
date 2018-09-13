package LibreCat::App::Catalogue::Route::publication;

=head1 NAME LibreCat::App::Catalogue::Route::publication

Route handler for publications.

=cut

use Catmandu::Sane;
use Catmandu;
use LibreCat qw(publication);
use Catmandu::Fix qw(expand);
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::Permission;
use Dancer qw(:syntax);
use Encode qw(encode);

sub access_denied_hook {
    h->hook('publication-access-denied')
        ->fix_around({_id => params->{id}, user_id => session->{user_id},});
}

=head1 PREFIX /record

All actions related to a publication record are handled under this prefix.

=cut

prefix '/librecat/record' => sub {

=head2 GET /new

Prints a list of available publication types + import form.

Some fields are pre-filled.

=cut

    get '/new' => sub {
        my $type = params->{type};
        my $user = h->get_person(session->{user_id});

        return template 'backend/add_new' unless $type;

        my $id = publication->generate_id;

        # set some basic values
        my $data = {
            _id        => $id,
            type       => $type,
            department => $user->{department},
            creator => {id => session->{user_id}, login => session->{user},},
            user_id => session->{user_id},
        };

        # Use config/hooks.yml to register functions
        # that should run before/after adding new publications
        # E.g. create a hooks to change the default fields
        state $hook = h->hook('publication-new');

        $hook->fix_before($data);

        #-- Fill out default fields ---

        if (session->{role} eq "user") {
            my $person = {
                first_name => $user->{first_name},
                last_name  => $user->{last_name},
                full_name  => $user->{full_name},
                id         => session->{user_id},
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

        if (params->{lang}) {
            $data->{lang} = params->{lang};
        }

        my $templatepath = "backend/forms";

        $data->{new_record} = 1;

        # -- end default fields ---

        $hook->fix_after($data);

        template "$templatepath/$type", $data;
    };

=head2 GET /edit/:id

Displays record for id.

Checks if the user has permission the see/edit this record.

=cut

    get '/edit/:id' => sub {

        my $rec = publication->get(param("id")) or pass;

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

        my $templatepath = "backend/forms";
        my $template     = $rec->{meta}->{template} // $rec->{type};

        $rec->{return_url} = request->referer if request->referer;

        # --- End setting edit mode

        $hook->fix_after($rec);

        template "$templatepath/$template", $rec;
    };

=head2 POST /update

Saves the record in the database.

Checks if the user has the rights to update this record.

=cut

    post '/update' => sub {
        my $p          = params;
        my $return_url = $p->{return_url};

        h->log->debug("Params:" . to_dumper($p));

        unless (
            $p->{new_record}
            or p->can_edit(
                $p->{_id},
                {user_id => session("user_id"), role => session("role")}
            )
            )
        {
            access_denied_hook();
            status '403';
            forward '/access_denied';
        }

        delete $p->{new_record};

        $p = h->nested_params($p);

        if ($p->{finalSubmit} eq 'recSubmit') {
            $p->{status} = 'submitted';
        }
        elsif ($p->{finalSubmit} eq 'recPublish') {
            $p->{status} = 'public';
        }
        elsif ($p->{finalSubmit} eq 'recReturn') {
            $p->{status} = 'returned';
        }

        $p->{user_id} = session("user_id");

        # Use config/hooks.yml to register functions
        # that should run before/after updating publications
        h->hook('publication-update')->fix_around(
            $p,
            sub {
                publication->add($p);
            }
        );

        redirect $return_url || uri_for('/librecat');
    };

=head2 GET /return/:id

Set status to 'returned'.

Checks if the user has the rights to edit this record.

=cut

    get '/return/:id' => sub {
        my $return_url = params->{return_url};

        my $rec = publication->get(param("id")) or pass;

        unless (
            p->can_edit(
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

        unless ($rec) {
            return template 'error',
                {message => "No publication found with ID $id."};
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

=head2 GET /preview/id

Prints the frontdoor for every record.

=cut

    get '/preview/:id' => sub {
        my $id = params->{id};

        my $hits = publication->get($id);

        $hits->{style}  = h->config->{citation}->{csl}->{default_style};
        $hits->{marked} = 0;

        template 'publication/record.tt', $hits;
    };

=head2 GET /internal_view/:id

Prints internal view, optionally as data dumper.

For admins only!

=cut

    get '/internal_view/:id' => sub {
        my $id = params->{id};

        my $rec = publication->get($id);

        unless ($rec) {
            return template 'error',
                {message => "No publication found with ID $id."};
        }

        my $export_string;
        my $exporter = Catmandu->exporter('YAML', file => \$export_string);
        $exporter->add($rec);

        return template 'backend/internal_view', {data => $export_string};
    };

=head2 GET /clone/:id

Clones the record with ID :id and returns a form with a different ID.

=cut

    get '/clone/:id' => sub {
        my $id  = params->{id};
        my $rec = publication->get($id);

        unless ($rec) {
            return template 'error',
                {message => "No publication found with ID $id."};
        }

        delete $rec->{file};
        delete $rec->{related_material};
        $rec->{_id}        = publication->generate_id;
        $rec->{new_record} = 1;

        my $template = $rec->{type} . ".tt";

        return template "backend/forms/$template", $rec;
    };

=head2 GET /publish/:id

Publishes private records, returns to the list.

=cut

    get '/publish/:id' => sub {
        my $return_url = params->{return_url};

        my $rec = publication->get(param("id")) or pass;

        unless (
            p->can_edit(
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

=head2 POST /change_mode

Changes the type of the publication.

=cut

    post '/change_type' => sub {
        my $params = params;

        $params->{file} = [$params->{file}]
            if ($params->{file} and ref $params->{file} ne "ARRAY");

        $params = h->nested_params($params);
        if ($params->{file}) {
            foreach my $fi (@{$params->{file}}) {
                $fi              = encode('UTF-8', $fi);
                $fi              = from_json($fi);
                $fi->{file_json} = to_json($fi);
            }
        }

        # Use config/hooks.yml to register functions
        # that should run before/after changing the edit mode
        state $hook = h->hook('publication-change-type');
        $hook->fix_before($params);
        $hook->fix_after($params);

        template "backend/forms/$params->{type}", $params;
    };

};

1;
