package App::Search::Route::feed;

use Catmandu::Sane;
use Try::Tiny;
use Dancer qw(:syntax);
use Dancer::Plugin::Feed;
use App::Helper;

get '/feed/:format' => sub {
    my $feed;
    try {
        my $hits = h->search_publication();
        $feed = create_feed(
            format  => params->{format},
            title   => h->config->{app},
            entries => [map {
                my $rec = $_;
                {title => $_->{title}}
            } @{$hits->{hits}}],
        );
    }
    catch {
        my ( $exception ) = @_;

        if ( $exception->does('FeedInvalidFormat') ) {
            return $exception->message;
        }
        elsif ( $exception->does('FeedNoFormat') ) {
            return $exception->message;
        }
        else {
            $exception->rethrow;
        }
    };

    return $feed;
};

1;
