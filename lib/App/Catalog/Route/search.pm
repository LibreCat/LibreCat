package App::Catalog::Route::search;

=head1 NAME

    App::Catalog::Route::search

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Catalog::Helper;
use App::Catalog::Controller::Search qw/search_publication/;

=head2 PREFIX /search

    All publication searches are handled within the
    prefix search.

=cut

prefix '/search' => sub {

=head2 GET /admin

    Performs search for admin.

=cut

    get '/admin' => sub {
        my $params = params;

        ( session->{role} ne "super_admin" )
            && ( redirect '/myPUB/reviewerSearch' );

        $params->{modus} = "admin";
        search_publication($params);

    };

=head2 GET /reviewer

    Performs search for reviewer.

=cut

        get '/reviewer' => sub {
        my $params = params;

        ( session->{role} ne "super_admin" and session->{role} ne "reviewer" )
            && ( redirect '/myPUB/search' );

        $params->{modus} = "reviewer";
        search_publication($params);

        };

=head2 GET /datamanager

    Performs search for data manager.

=cut

        get '/datamanager' => sub {
        my $params = params;

        (           session->{role} ne "super_admin"
                and session->{role} ne "dataManager" )
            && ( redirect '/myPUB/search' );

        $params->{modus} = "dataManager";
        search_publication($params);

        };

=head2 GET /

    Performs search for user.

=cut

        get '/' => sub {
        my $params = params;

        $params->{modus} = "user";
        search_publication($params);

        };

};

1;
