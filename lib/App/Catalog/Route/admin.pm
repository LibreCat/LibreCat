package App::Catalog::Route::admin;

use Catmandu::Sane;
use Catmandu::Util qw(trim);
use Dancer ':syntax';
use App::Catalog::Helper;
use App::Catalog::Controller::Admin qw/:all/;

prefix '/admin' => sub {

    # manage accounts
    get '/account' => sub {
        template 'admin/account';
    };

    get '/account/new' => sub {
        my $id = new_person();
        template 'admin/edit_account', { _id => $id };
    };

    get '/account/search' => sub {
        my $p    = params;
        my $hits = search_person($p);
        template 'admin/account', $hits;
    };

    get '/account/edit/:id' => sub {
        my $id     = param 'id';
        my $person = edit_person($id);
        template 'admin/edit_account', $person;
    };

    post '/account/update' => sub {
        my $p = params;
        $p = h->nested_params($p);

        update_person($p);
        template 'admin/account';
    };

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

=head1 PREFIX /admin

    Permission: for admins only. Every other user will get a 403.

=head2 GET /account

    Prints a search form for the authority database.

=head2 GET /account/new

    Opens an empty form. The ID is automatically generated.

=head2 GET /account/search

    Searches the authority database. Prints the search form + result list.

=head2 GET /account/edit/:id

    Opens the record with ID id. Cancel returns to /account.
    Save does a POST on /account/update.

=head2 POST /account/update

    Saves the data in the authority database.

=head2 GET /account/import

    Input is person id. Returns warning if person is alread in the database.
    Otherwise opens a form with data imported from PEVZ.

=cut
