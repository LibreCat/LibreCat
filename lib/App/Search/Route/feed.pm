package App::Search::Route::feed;

use Catmandu::Sane;
use Catmandu::Fix qw(publication_to_dc);
use Dancer qw(:syntax);
use DateTime;
use XML::RSS;
use Encode;
use App::Helper;

get '/feed' => sub {
    state $fix = Catmandu::Fix->new(fixes => ['publication_to_dc()']);

    my $now = DateTime->now->truncate(to => 'week');

    my $p = h->extract_params();
	push @{$p->{q}},
        ( "status exact public",
        "date_updated>". $now->strftime('"%FT%H:%M:00Z"') );

    my $rss = XML::RSS->new;

    $rss->channel(
        link => h->host,
        title => h->config->{app},
        syn => {
            updatePeriod => 'weekly',
            updateFrequency => "1",
            updateBase => "2000-01-01T00:00+00:00",
        }
    );

    my $hits = h->search_publication($p);
    $hits->each( sub {
        my $hit = $_[0];

	    if ($hit->{_id} && $hit->{citation}->{apa}) {
            $rss->add_item(
                link => h->host . "/publication/$hit->{_id}",
                title => $hit->{citation}->{apa},
                dc => $fix->fix($hit),
            );
	    }
    });

    content_type 'xhtml';
    return $rss->as_string;
};

1;
