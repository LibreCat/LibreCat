package App::Search::Route::ajax;

=head1 NAME

App::Search::Route::ajax - handles routes for  asynchronous requests

=cut

use Catmandu::Sane;
use Catmandu::Util qw(join_path);
use Dancer qw/:syntax/;
use Dancer::Plugin::Ajax;
use App::Helper;

=head2 AJAX /metrics/:id

Web of Science 'Times Cited' information

=cut
ajax '/metrics/:id' => sub {
    my $metrics = h->get_metrics('wos', params->{id});
    return to_json {
        times_cited => $metrics->{times_cited},
        citing_url => $metrics->{citing_url},
    };
};

1;
