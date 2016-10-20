package LibreCat::App::Catalogue::Route::publication;

=head1 NAME LibreCat::App::Catalogue::Route::publication

Route handler for publications.

=cut

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Catmandu::Fix qw(expand);
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::Permission;
use Dancer qw(:syntax);
use Encode qw(encode);
use Dancer::Plugin::Auth::Tiny;

Dancer::Plugin::Auth::Tiny->extend(
    role => sub {
        my ($role, $coderef) = @_;
        return sub {
            if (session->{role} && $role eq session->{role}) {
                goto $coderef;
            }
            else {
                redirect '/access_denied';
            }
        }
    }
);

=head1 PREFIX /record

All actions related to a publication record are handled under this prefix.

=cut

prefix '/librecat/record' => sub {

=head2 GET /new

Prints a list of available publication types + import form.

Some fields are pre-filled.

=cut

    get '/new' => needs login => sub {
        my $type      = params->{type};
        my $user      = h->get_person(session->{personNumber});
        my $edit_mode = params->{edit_mode} || $user->{edit_mode} || "";

        return template 'backend/add_new' unless $type;

        my $id = h->new_record('publication');

        # set some basic values
        my $data = {
            _id        => $id,
            type       => $type,
            department => $user->{department},
            creator =>
                {id => session->{personNumber}, login => session->{user},},
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
                id         => session->{personNumber},
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

        if ($type eq "research_data" && h->config->{doi}) {
            $data->{doi} = h->config->{doi}->{prefix} . "/" . $id;
        }

        if (params->{lang}) {
            $data->{lang} = params->{lang};
        }

        my $templatepath = "backend/forms";

        if (   ($edit_mode and $edit_mode eq "expert")
            or ($edit_mode eq "" and session->{role} eq "super_admin"))
        {
            $templatepath .= "/expert";
        }

        $data->{new_record} = 1;

        # -- end default fields ---

        $hook->fix_after($data);

        template "$templatepath/$type", $data;
    };

=head2 GET /edit/:id

Displays record for id.

Checks if the user has permission the see/edit this record.

=cut

    get '/edit/:id' => needs login => sub {
        my $id = param 'id';

        unless (p->can_edit($id, session->{user}, session->{role})) {
            status '403';
            forward '/access_denied', {referer => request->{referer}};
        }


        forward '/' unless $id;

        my $rec = h->publication->get($id);

        unless ($rec) {
            return template 'error', {
                message => "No publication found with ID $id."
            };
        }

        # Use config/hooks.yml to register functions
        # that should run before/after edit publications
        state $hook = h->hook('publication-edit');

        $hook->fix_before($rec);

        # --- Setting the edit mode ---
        my $person       = h->get_person(session->{personNumber});
        my $edit_mode    = params->{edit_mode} || $person->{edit_mode};
        my $templatepath = "backend/forms";
        my $template     = $rec->{type} . ".tt";

        if (   ($edit_mode and $edit_mode eq "expert")
            or (!$edit_mode and session->{role} eq "super_admin"))
        {
            $templatepath .= "/expert";
            $edit_mode = "expert";
        }

        $rec->{return_url} = request->{referer} if request->{referer};

        $rec->{edit_mode} = $edit_mode if $edit_mode;
        # --- End setting edit mode

        $hook->fix_after($rec);

        template "$templatepath/$template", $rec;
    };

=head2 POST /update

Saves the record in the database.

Checks if the user has the rights to update this record.

=cut

    post '/update' => needs login => sub {
        my $p = params;

        unless ($p->{new_record}
            or p->can_edit($p->{_id}, session->{user}, session->{role}))
        {
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

        # Use config/hooks.yml to register functions
        # that should run before/after updating publications
        h->hook('publication-update')->fix_around($p, sub {
            h->update_record('publication', $p);
        });

        redirect '/librecat';
    };

=head2 GET /return/:id

Set status to 'returned'.

Checks if the user has the rights to edit this record.

=cut

    get '/return/:id' => needs login => sub {
        my $id = params->{id};

        unless (p->can_edit($id, session->{user}, session->{role})) {
            status '403';
            forward '/access_denied';
        }

        my $rec = h->publication->get($id);

        $rec->{status} = "returned";

        # Use config/hooks.yml to register functions
        # that should run before/after returning publications
        state $hook = h->hook('publication-return');

        $hook->fix_before($rec);

        my $res = h->update_record('publication', $rec);

        $hook->fix_after($res);

        redirect '/librecat';
    };

=head2 GET /delete/:id

Deletes record with id. For admins only.

=cut

    get '/delete/:id' => needs role => 'super_admin' => sub {
        my $id         = params->{id};
        my $record     = h->publication->get($id);

        # Use config/hooks.yml to register functions
        # that should run before/after deleting publications
        state $hook = h->hook('publication-delete');

        $hook->fix_before($record);

        my $res = h->delete_record('publication', $id);

        $hook->fix_after($res);

        redirect '/librecat';
    };

=head2 GET /preview/id

Prints the frontdoor for every record.

=cut

    get '/preview/:id' => needs login => sub {
        my $id = params->{id};

        my $hits = h->publication->get($id);

        $hits->{bag}    = $hits->{type} eq "research_data" ? "data" : "publication";
        $hits->{style}  = h->config->{default_fd_style} || "default";
        $hits->{marked} = 0;

        template 'publication/record.tt', $hits;
    };

=head2 GET /internal_view/:id

Prints internal view, optionally as data dumper.

For admins only!

=cut

    get qr{/internal_view/(\w{1,})/*} => needs role => 'super_admin' => sub {
        my ($id) = splat;

        return template 'backend/internal_view', {
                data => to_yaml h->publication->get($id)
        };
    };

=head2 GET /publish/:id

Publishes private records, returns to the list.

=cut

    get '/publish/:id' => needs login => sub {
        my $id = params->{id};

        unless (p->can_edit($id, session->{user}, session->{role})) {
            status '403';
            forward '/access_denied';
        }

        my $record     = h->publication->get($id);
        my $old_status = $record->{status};

        if (session->{role} eq "super_admin") {
            $record->{status} = "public";
        }
        elsif ($record->{type} eq "research_data") {
            $record->{status} = "submitted" if $old_status eq "private";
        }
        else {
            $record->{status} = "public";
        }

        if ($record->{status} ne $old_status) {
            # Use config/hooks.yml to register functions
            # that should run before/after publishing publications
            state $hook = h->hook('publication-publish');

            $hook->fix_before($record);

            my $res = h->update_record('publication', $record);

            $hook->fix_after($res);
        }

        redirect '/librecat';
    };

=head2 GET /change_mode

Changes the layout of the edit form.

=cut

    post '/change_mode' => needs login => sub {
        my $mode   = params->{edit_mode};
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
        state $hook = h->hook('publication-change-mode');

        $hook->fix_before($params);

        Catmandu::Fix->new(
            fixes => [
                'publication_identifier()',
                'external_id()',
                'page_range_number()',
                'clean_preselects()',
                'split_field(nasc, " ; ")',
                'split_field(genbank, " ; ")',
                'split_field(keyword, " ; ")',
                'delete_empty()',
            ]
        )->fix($params);

        my $person = h->get_person(session('personNumber'));
        if ($mode eq "normal" or $mode eq "expert") {
            $person->{edit_mode} = $mode;
            h->update_record('researcher', $person);
        }

        my $path = "backend/forms/";
        $path .= "expert/" if $mode eq "expert";
        $path .= params->{type} . ".tt";

        $hook->fix_after($params);

        template $path, $params;
    };

};

1;
