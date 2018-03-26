package LibreCat::App::Catalogue::Route::admin;

=head1 NAME

LibreCat::App::Catalogue::Route::admin - Route handler for admin actions

=cut

use Catmandu::Sane;
use LibreCat;
use Catmandu::Util qw(trim);
use App::bmkpasswd qw(mkpasswd);
use Dancer ':syntax';
use LibreCat::App::Helper;

=head1 PREFIX /librecat/admin

Permission: for admins only. Every other user will get a 403.

=cut

prefix '/librecat/admin' => sub {

=head2 GET /account

Prints a search form for the authority database.

=cut

    get '/account' => sub {
        template 'admin/account';
    };

=head2 GET /account/new

Opens an empty form. The ID is automatically generated.

=cut

    get '/account/new' => sub {
        template 'admin/forms/edit_account',
            {_id => LibreCat->user->generate_id};
    };

=head2 GET /account/search

Searches the authority database. Prints the search form + result list.

=cut

    get '/account/search' => sub {
        my $p = params;
        h->log->debug("query for researcher: " . to_dumper($p));
        my $hits = LibreCat->searcher->search('user', $p);
        template 'admin/account', $hits;
    };

=head2 GET /account/edit/:id

Opens the record with ID id.

=cut

    get '/account/edit/:id' => sub {
        my $person = LibreCat->user->get(params->{id});
        template 'admin/forms/edit_account', $person;
    };

=head2 POST /account/update

Saves the data in the authority database.

=cut

    post '/account/update' => sub {
        my $p = params;

        $p = h->nested_params($p);

        # if password and not yet encrypted
        $p->{password} = mkpasswd($p->{password})
            if ($p->{password} and $p->{password} !~ /\$.{15,}/);

        LibreCat->user->add($p);
        template 'admin/account';
    };

=head2 GET /account/delete/:id

Deletes the account with ID :id.

=cut

    get '/account/delete/:id' => sub {
        LibreCat->user->delete(params->{id});
        redirect uri_for('/librecat');
    };

    get '/project' => sub {
        my $hits = LibreCat->searcher->search('project',
            {q => "", limit => 100, start => params->{start} || 0});
        template 'admin/project', $hits;
    };

    get '/project/new' => sub {
        template 'admin/forms/edit_project',
            {_id => LibreCat->project->generate_id};
    };

    get '/project/search' => sub {
        my $p = h->extract_params();

        my $hits = LibreCat->searcher->search('project', $p);

        template 'admin/project', $hits;
    };

    get '/project/edit/:id' => sub {
        my $project = LibreCat->project->get(params->{id});
        template 'admin/forms/edit_project', $project;
    };

    post '/project/update' => sub {
        my $p      = h->nested_params();
        my $return = LibreCat->project->add($p);
        redirect uri_for('/librecat/admin/project');
    };

    get '/research_group' => sub {
        my $hits = LibreCat->searcher->search('research_group',
            {q => "", limit => 100, start => params->{start} || 0});
        template 'admin/research_group', $hits;
    };

    get '/research_group/new' => sub {
        template 'admin/forms/edit_research_group',
            {_id => LibreCat->research_group->generate_id};
    };

    get '/research_group/search' => sub {
        my $p = h->extract_params();

        my $hits = LibreCat->searcher->search('research_group', $p);

        template 'admin/research_group', $hits;
    };

    get '/research_group/edit/:id' => sub {
        my $research_group = LibreCat->research_group->get(params->{id});
        template 'admin/forms/edit_research_group', $research_group;
    };

    post '/research_group/update' => sub {
        my $p      = h->nested_params();
        my $return = LibreCat->research_group->add($p);
        redirect uri_for('/librecat/admin/research_group');
    };

};

1;
