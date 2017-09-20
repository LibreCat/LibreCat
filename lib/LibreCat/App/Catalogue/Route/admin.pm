package LibreCat::App::Catalogue::Route::admin;

=head1 NAME

LibreCat::App::Catalogue::Route::admin - Route handler for admin actions

=cut

use Catmandu::Sane;
use Catmandu::Util qw(trim);
use App::bmkpasswd qw(mkpasswd);
use Dancer ':syntax';
use LibreCat::App::Helper;

=head1 PREFIX /librecat/admin

Permission: for admins only. Every other user will get a 403.

=cut

prefix '/librecat/admin' => sub {

    my $user_bag    = Catmandu->store('main')->bag('user');
    my $project_bag = Catmandu->store('main')->bag('project');
    my $rg_bag      = Catmandu->store('main')->bag('research_group');

=head2 GET /account

Prints a search form for the user database.

=cut

    get '/account' => sub {
        template 'admin/account';
    };

=head2 GET /account/new

Opens an empty form. The ID is automatically generated.

=cut

    get '/account/new' => sub {
        template 'admin/forms/edit_account', {_id => $user_bag->generate_id};
    };

=head2 GET /account/search

Searches the authority database. Prints the search form + result list.

=cut

    get '/account/search' => sub {
        my $p = params;
        h->log->debug("query for user: " . to_dumper($p));
        my $hits = LibreCat->searcher->search('user', $p);

        template 'admin/account', $hits;
    };

=head2 GET /account/edit/:id

Opens the record with ID id.

=cut

    get '/account/edit/:id' => sub {
        my $person = $user_bag->get(params->{id});

        template 'admin/forms/edit_account', $person;
    };

=head2 POST /account/update

Saves the data in the authority database.

=cut

    post '/account/update' => sub {
        my $data = params;

        $data = h->nested_params($data);

        # if password and not yet encrypted
        $data->{password} = mkpasswd($data->{password})
            if ($data->{password} and $data->{password} !~ /\$.{15,}/);

        LibreCat->hook('user-update')->fix_around(
            $data,
            sub {
                if ($data->{_validation_errors}) {

                    # error handling
                }
                else {
                    $user_bag->add($data);
                }
            }
        );

        template 'admin/account';
    };

=head2 GET /account/delete/:id

Deletes the account with ID :id.

=cut

    get '/account/delete/:id' => sub {
        $user_bag->delete(params->{id}) if params->{id};

        redirect uri_for('/librecat');
    };

    get '/project' => sub {
        my $hits = LibreCat->searcher->search('project',
            {q => "", limit => 100, start => params->{start} || 0});
        template 'admin/project', $hits;
    };

=head1 PROJECT

=cut

    get '/project/new' => sub {
        template 'admin/forms/edit_project',
            {_id => $project_bag->generate_id};
    };

    get '/project/search' => sub {
        my $p = h->extract_params();

        my $hits = LibreCat->searcher->search('project', $p);

        template 'admin/project', $hits;
    };

    get '/project/edit/:id' => sub {
        my $project = $project_bag->get(params->{id});

        template 'admin/forms/edit_project', $project;
    };

    post '/project/update' => sub {
        my $data = h->nested_params();

        LibreCat->hook('project-update')->fix_around(
            $data,
            sub {
                if ($data->{_validation_errors}) {

                    # error handling
                }
                else {
                    $project_bag->add($data);
                }
            }
        );

        redirect uri_for('/librecat/admin/project');
    };

=head1 REASEARCH GROUP

=cut

    get '/research_group' => sub {
        my $hits = LibreCat->searcher->search('research_group',
            {q => "", limit => 100, start => params->{start} || 0});

        template 'admin/research_group', $hits;
    };

    get '/research_group/new' => sub {
        template 'admin/forms/edit_research_group',
            {_id => $rg_bag->generate_id};
    };

    get '/research_group/search' => sub {
        my $p = h->extract_params();

        my $hits = LibreCat->searcher->search('research_group', $p);

        template 'admin/research_group', $hits;
    };

    get '/research_group/edit/:id' => sub {
        my $research_group = $rg_bag->get(params->{id});

        template 'admin/forms/edit_research_group', $research_group;
    };

    post '/research_group/update' => sub {
        my $data = h->nested_params();

        LibreCat->hook('research_group-update')->fix_around(
            $data,
            sub {
                if ($data->{_validation_errors}) {

                    # error handling
                }
                else {
                    $rg_bag->add($data);
                }
            }
        );

        redirect uri_for('/librecat/admin/research_group');
    };

};

1;
