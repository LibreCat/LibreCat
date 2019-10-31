package LibreCat::App::Catalogue::Route::admin;

=head1 NAME

LibreCat::App::Catalogue::Route::admin - Route handler for admin actions

=cut

use Catmandu::Sane;
use LibreCat qw(searcher user project research_group);
use Catmandu::Util qw(trim :is);
use App::bmkpasswd qw(mkpasswd);
use Dancer ':syntax';
use LibreCat::App::Helper;

=head1 PREFIX /librecat/admin

Permission: for admins only. Every other user will get a 403.

=cut

prefix '/librecat/admin' => sub {

=head2 GET /account

Searches the authority database. Prints the search form + result list.

=cut

    get '/account' => sub {
        my $p = params;
        h->log->debug("query for researcher: " . to_dumper($p));
        my $hits = searcher->search('user', $p);
        template 'admin/account', $hits;
    };

=head2 GET /account/new

Opens an empty form. The ID is automatically generated.

=cut

    get '/account/new' => sub {
        template 'admin/forms/edit_account', {};
    };

=head2 GET /account/edit/:id

Opens the record with ID id.

=cut

    get '/account/edit/:id' => sub {
        my $person = user->get(params->{id});
        template 'admin/forms/edit_account', $person;
    };

=head2 PUT /account/:id

Updates (existing) user in the authority database.

Redirects to /librecat/admin/account

=cut

    put '/account/:id' => sub {

        my $id = param("id");
        my $user = user->get($id) or pass;

        my $p = params("body");
        $p = h->nested_params($p);
        $p->{_id} = $user->{_id};

        if (is_string $p->{password}) {
            #update password when given
            $p->{password} = mkpasswd($p->{password});
        }
        else {
            $p->{password} = $user->{password};
        }

        user->add($p);

        redirect h->uri_for("/librecat/admin/account");

    };

=head2 POST /account

Creates new user in the authority database.

Redirects to /librecat/admin/account

=cut

    post '/account' => sub {

        my $p = params("body");

        $p             = h->nested_params($p);
        $p->{_id}      = user->generate_id;
        $p->{password} = mkpasswd($p->{password}) if is_string($p->{password});

        user->add($p);

        redirect h->uri_for("/librecat/admin/account");

    };

=head2 GET /account/delete/:id

Deletes the account with ID :id.

=cut

    get '/account/delete/:id' => sub {
        user->delete(params->{id});
        redirect uri_for('/librecat');
    };

    get '/project/new' => sub {
        template 'admin/forms/edit_project', {_id => project->generate_id};
    };

    get '/project' => sub {
        my $p = h->extract_params();

        my $hits = searcher->search('project', $p);

        template 'admin/project', $hits;
    };

    get '/project/edit/:id' => sub {
        my $project = project->get(params->{id});
        template 'admin/forms/edit_project', $project;
    };

    post '/project/update' => sub {
        my $p = h->nested_params();
        project->add($p);
        redirect uri_for('/librecat/admin/project');
    };

    get '/research_group/new' => sub {
        template 'admin/forms/edit_research_group',
            {_id => research_group->generate_id};
    };

    get '/research_group' => sub {
        my $p = h->extract_params();

        my $hits = searcher->search('research_group', $p);

        template 'admin/research_group', $hits;
    };

    get '/research_group/edit/:id' => sub {
        my $research_group = research_group->get(params->{id});
        template 'admin/forms/edit_research_group', $research_group;
    };

    post '/research_group/update' => sub {
        my $p = h->nested_params();
        research_group->add($p);
        redirect uri_for('/librecat/admin/research_group');
    };

};

1;
