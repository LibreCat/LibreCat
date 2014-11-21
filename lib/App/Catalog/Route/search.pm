package App::Catalog::Route::search;

=head1 NAME

    App::Catalog::Route::search

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;
use App::Catalog::Controller::Search qw/search_publication/;
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

=head2 PREFIX /myPUB/search

    All publication searches are handled within the
    prefix search.

=cut
prefix '/myPUB/search' => sub {

=head2 GET /admin

    Performs search for admin.

=cut
    get '/admin' => needs role => 'super_admin' => sub {
        my $params = params;

        $params->{modus} = "admin";
        search_publication($params);

    };

=head2 GET /reviewer

    Performs search for reviewer.

=cut
        get '/reviewer' => needs role => 'reviewer' => sub {
        my $params = params;

        $params->{modus} = "reviewer";
        search_publication($params);

    };

=head2 GET /datamanager

    Performs search for data manager.

=cut
        get '/datamanager' => needs role => 'dataManager' => sub {
        my $params = params;

        $params->{modus} = "dataManager";
        search_publication($params);

    };

=head2 GET '/delegate/:delegate_id'

    Performs a search of records for delegated person's
    publications.

=cut
    get '/delegate/:delegate_id' => sub {
        my $params = params;

        $params->{modus} = "delegate_".$params->{delegate_id};
        search_publication($params);
    };

=head2 GET /

    Performs search for user.

=cut
        get '/' => needs login => sub {
        my $params = params;

        $params->{modus} = "user";
        search_publication($params);

    };

};

1;
