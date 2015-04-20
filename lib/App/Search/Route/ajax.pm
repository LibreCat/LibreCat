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

=head2 AJAX /thumbnail/:id

Thumbnail for frontdoor

=cut
get '/thumbnail/:id' => sub {
    my $path = h->get_file_path(params->{id});
    my $thumb = join_path($path, 'thumbnail.png');
    if ( -e $thumb ) {
        send_file $thumb,
            system_path  => 1,
            content_type => 'image/png';
    } else {
        #status 'not_found';
        send_file "public/images/bookDummy.png",
            system_path => 1,
            content_type => 'image/png';
    }
};

# ajax '/citiaton/:id/:fmt' => sub {
#     my $pub = h->publication->get(params->{id});
#     to_json {cit => export_to_string(....)};
# };

1;
