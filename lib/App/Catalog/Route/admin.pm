package App::Catalog::Route::admin;

=head1 NAME

    App::Catalog::Route::admin - Route handler for admin actions

=cut

use Catmandu::Sane;
use Catmandu::Util qw(trim);
use Dancer ':syntax';
use App::Catalog::Helper;
use App::Catalog::Controller::Admin qw/:all/;
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

=head1 PREFIX /myPUB/admin

    Permission: for admins only. Every other user will get a 403.

=cut
prefix '/myPUB/admin' => sub {

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
        my $id = new_person();
        template 'admin/edit_account', { _id => $id };
    };

=head2 GET /account/search

    Searches the authority database. Prints the search form + result list.

=cut
    get '/account/search' => needs role => 'super_admin' => sub {
        my $p    = params;
        my $hits = search_person($p);
        template 'admin/account', $hits;
    };

=head2 GET /account/edit/:id

    Opens the record with ID id. Cancel returns to /account.
    Save does a POST on /account/update.

=cut
    get '/account/edit/:id' => needs role => 'super_admin' => sub {
        my $id     = param 'id';
        my $person = edit_person($id);
        template 'admin/edit_account', $person;
    };

=head2 POST /account/update

    Saves the data in the authority database.

=cut
    post '/account/update' => needs role => 'super_admin' => sub {
        my $p = params;
        $p = h->nested_params($p);

        update_person($p);
        template 'admin/account';
    };

=head2 GET /account/import

    Input is person id. Returns warning if person is already in the database.

=cut
    get '/account/import' => needs role => 'super_admin' => sub {
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

    get '/import' => sub {
        return "Not implemented.";
    };
    
    get '/project' => needs role => 'super_admin' => sub {
    	my $hits = h->search_project({q => "", limit => 100});
        template 'admin/project', $hits;
    };
    
    get '/project/search' => sub {
        my $params = params;
        my $p;
        
        $p->{q} = $params->{q} || "";
        $p->{limit} = $params->{limit} || h->config->{default_searchpage_size};
        $p->{start} = $params->{start} || 0;
        my $hits = h->search_project($p);
        
        template 'admin/project', $hits;
    };
    
    get '/project/edit/:id' => needs role => 'super_admin' => sub {
        my $id     = param 'id';
        my $project = edit_project($id);
        template 'admin/edit_project', $project;
    };
    
    post '/project/update' => needs role => 'super_admin' => sub {
    	my $params = params;
    	my $return = update_project($params);
    	return to_dumper $return;
    	redirect '/myPUB/admin/project/';
    };

    # manage departments
    get '/department' => sub { };

    # monitoring external sources
    get '/inspire-monitor' => sub { };
};

1;
