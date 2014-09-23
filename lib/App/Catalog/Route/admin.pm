package App::Catalog::Route::admin;

=head1 NAME

    App::Catalog::Route::admin - Route handler for admin actions

=cut

use Catmandu::Sane;
use Catmandu::Util qw(trim);
use Dancer ':syntax';
use App::Catalog::Helper;
use App::Catalog::Controller::Admin qw/:all/;

=head1 PREFIX /admin

    Permission: for admins only. Every other user will get a 403.

=cut
prefix '/admin' => sub {

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
        my $id = new_person();
        template 'admin/edit_account', { _id => $id };
    };

=head2 GET /account/search

    Searches the authority database. Prints the search form + result list.

=cut
    get '/account/search' => sub {
        my $p    = params;
        my $hits = search_person($p);
        template 'admin/account', $hits;
    };

=head2 GET /account/edit/:id

    Opens the record with ID id. Cancel returns to /account.
    Save does a POST on /account/update.

=cut
    get '/account/edit/:id' => sub {
        my $id     = param 'id';
        my $person = edit_person($id);
        template 'admin/edit_account', $person;
    };

=head2 POST /account/update

    Saves the data in the authority database.

=cut
    post '/account/update' => sub {
        my $p = params;
        $p = h->nested_params($p);

        update_person($p);
        template 'admin/account';
    };

=head2 GET /account/import

    Input is person id. Returns warning if person is already in the database.

=cut
    get '/account/import' => sub {
        my $id = trim params->{id};

        my $person_in_db = h->authority_admin->get($id);
        if ($person_in_db) {
            template 'admin/account',
                { error => "There is already an account with ID $id." };
        }
        else {
            my $p = import_person($id);
            template 'admin/edit_account', $p;
        }
    };

    # manage departments
    get '/admin/department' => sub { };

    # monitoring external sources
    get '/inspire-monitor' => sub { };
};

1;
