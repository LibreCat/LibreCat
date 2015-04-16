package App::Search::Route::feed;

use Catmandu::Sane;
use Catmandu::Fix qw(publication_to_dc);
use Dancer qw(:syntax);
#use DateTime;
#use XML::RSS;
#use Encode;
use Dancer::Plugin::Feed;
use App::Helper;

get '/feed/:format' => sub {

    state $fix = Catmandu::Fix->new(fixes => ['publication_to_dc()']);

    my $feed;
    try {
        $feed = create_feed(
            format  => params->{format},
            title   => 'my great feed',
            entries => [ map { title => "entry $_" }, 1 .. 10 ],
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

__END__
    my $p;
    my $q = params->{'q'} ||= 'submissionStatus exact public';
    $p = {
        q => $q . ' AND dateLastChanged > '. $now->strftime('"%F %H:%M:00"'),
        start => 0,
        limit => params->{'limit'} ||= h->config->{store}->{default_page_size},
    };

    my $rss = XML::RSS->new;

    $rss->channel(
        link => h->host,
        title => h->config->{app},
        description => h->config->{institution}->{name_eng}." ".h->config->{app},
        syn => {
            updatePeriod => $period,
            updateFrequency => "1",
            updateBase => "2000-01-01T00:00+00:00",
        }
    );
    my $hits = h->search_publication($p);
    $hits->each( sub {
        my $hit = $_[0];

	    if ($hit->{_id} && $hit->{citation}->{apa}) {
            $rss->add_item(
            link  => h->host . "/publication/$hit->{_id}",
            title => $hit->{citation}->{apa},
            dc    => $fix->fix($hit),
            );
	    }
    });

    content_type 'xhtml';
    return $rss->as_string;
};

1;
