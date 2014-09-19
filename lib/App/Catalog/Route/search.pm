package App::Catalog::Route::search;

=head1 NAME

    App::Catalog::Route::search

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Catalog::Helper;
use App::Catalog::Controller::Search;

=head2 PREFIX /search
=cut

=head2 GET /search/admin
=cut
get '/adminSearch' => sub {
    my $params = params;

    (session->{role} ne "super_admin") && (redirect '/myPUB/reviewerSearch');

    $params->{modus} = "admin";
    search($params);

};

=head2 GET /search/reviewer
=cut
get '/reviewerSearch' => sub {
    my $params = params;

    (session->{role} ne "super_admin" and session->{role} ne "reviewer")
    	&& (redirect '/myPUB/search');

    $params->{modus} = "reviewer";
    search($params);

};

=head2 GET /search/reviewer
=cut
get '/datamanagerSearch' => sub {
    my $params = params;

    (session->{role} ne "super_admin" and session->{role} ne "dataManager")
    	&& (redirect '/myPUB/search');

    $params->{modus} = "dataManager";
    search($params);

};

=head2 GET /search
=cut
get '/search' => sub {
    my $params = params;

    $params->{modus} = "user";
    search($params);

};

1;
