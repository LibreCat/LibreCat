package LibreCat::App::Catalogue::Route::admin;

=head1 NAME

LibreCat::App::Catalogue::Route::admin - Route handler for admin actions

=cut

use Catmandu::Sane;
use Catmandu::Util qw(trim);
use App::bmkpasswd qw(mkpasswd);
use Dancer ':syntax';
use LibreCat::App::Helper;
use Dancer::Plugin::Auth::Tiny;
use Syntax::Keyword::Junction 'any' => {-as => 'any_of'};

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
        };
    },

    any_role => sub {
        my $coderef         = pop;
        my @requested_roles = @_;
        return sub {
            if (any_of(@requested_roles) eq session->{role}) {
                goto $coderef;
            }
            else {
                redirect '/access_denied';
            }
        };
    }
);

=head1 PREFIX /librecat/admin

Permission: for admins only. Every other user will get a 403.

=cut

prefix '/librecat/admin' => sub {

=head2 GET /account

Prints a search form for the authority database.

=cut

    get '/account' => needs role => 'super_admin' => sub {
        template 'admin/account';
    };

=head2 GET /account/new

Opens an empty form. The ID is automatically generated.

=cut

    get '/account/new' => needs role => 'super_admin' => sub {
        template 'admin/forms/edit_account',
            {_id => h->new_record('researcher')};
    };

=head2 GET /account/search

Searches the authority database. Prints the search form + result list.

=cut

    get '/account/search' => needs role => 'super_admin' => sub {
        my $p = params;
        h->log->debug("query for researcher: " . to_dumper($p));
        my $hits = LibreCat->searcher->search('researcher', $p);
        template 'admin/account', $hits;
    };

=head2 GET /account/edit/:id

Opens the record with ID id. Cancel returns to /account.
Save does a POST on /account/update.

=cut

    get '/account/edit/:id' => needs role => 'super_admin' => sub {
        my $person = h->researcher->get(params->{id});
        template 'admin/forms/edit_account', $person;
    };

=head2 POST /account/update

Saves the data in the authority database.

=cut

    post '/account/update' => needs role => 'super_admin' => sub {
        my $p = params;

        $p = h->nested_params($p);

        # if password and not yet encrypted
        $p->{password} = mkpasswd($p->{password})
            if ($p->{password} and $p->{password} !~ /\$.{15,}/);

        h->update_record('researcher', $p);
        template 'admin/account';
    };

=head2 GET /account/delete/:id

Deletes the account with ID :id.

=cut

    get '/account/delete/:id' => needs role => 'super_admin' => sub {
        h->delete_record('researcher', params->{id});
        redirect '/librecat';
    };

=head2 GET /account/import

Input is person id. Returns warning if person is already in the database.

=cut

    get '/account/import' => needs role => 'super_admin' => sub {
        # todo: was Bielefeld specific....
        template 'admin/account';
    };

    get '/project' => needs role => 'super_admin' => sub {
        my $hits = LibreCat->searcher->search('project',
            {q => "", limit => 100, start => params->{start} || 0});
        template 'admin/project', $hits;
    };

    get '/project/new' => needs role => 'super_admin' => sub {
        template 'admin/forms/edit_project',
            {_id => h->new_record('project')};
    };

    get '/project/search' => sub {
        my $p = h->extract_params();

        my $hits = hLibreCat->searcher->search('project', $p);

        template 'admin/project', $hits;
    };

    get '/project/edit/:id' => needs role => 'super_admin' => sub {
        my $project = h->project->get(params->{id});
        template 'admin/forms/edit_project', $project;
    };

    post '/project/update' => needs role => 'super_admin' => sub {
        my $p = h->nested_params();
        my $return = h->update_record('project', $p);
        redirect '/librecat/admin/project';
    };

    get '/research_group' => needs role => 'super_admin' => sub {
        my $hits = LibreCat->searcher->search('research_group',
            {q => "", limit => 100, start => params->{start} || 0});
        template 'admin/research_group', $hits;
    };

    get '/research_group/new' => needs role => 'super_admin' => sub {
        template 'admin/forms/edit_research_group',
            {_id => h->new_record('research_group')};
    };

    get '/research_group/search' => sub {
        my $p = h->extract_params();

        my $hits = LibreCat->searcher->search('research_group', $p);

        template 'admin/research_group', $hits;
    };

    get '/research_group/edit/:id' => needs role => 'super_admin' => sub {
        my $research_group = h->research_group->get(params->{id});
        template 'admin/forms/edit_research_group', $research_group;
    };

    post '/research_group/update' => needs role => 'super_admin' => sub {
        my $p = h->nested_params();
        my $return = h->update_record('research_group', $p);
        redirect '/librecat/admin/research_group';
    };

    get '/department' => needs role => 'super_admin' => sub {
        my $hits = LibreCat->searcher->search('department',
            {q => "", limit => 100, start => params->{start} || 0});
        template 'admin/department', $hits;
    };

    get '/department/new' => needs role => 'super_admin' => sub {
        template 'admin/forms/edit_department',
            {_id => h->new_record('department')};
    };

    get '/department/search' => sub {
        my $p = h->extract_params();

        my $hits = LibreCat->searcher->search('department', $p);

        template 'admin/department', $hits;
    };

    get '/department/edit/:id' => needs role => 'super_admin' => sub {
        my $department = h->department->get(params->{id});
        template 'admin/forms/edit_department', $department;
    };

    post '/department/update' => needs role => 'super_admin' => sub {
        my $p = h->nested_params();
        my $return = h->update_record('department', $p);
        redirect '/librecat/admin/department';
    };

};

1;
