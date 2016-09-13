package LibreCat::App::Search::Route::feed;

use Catmandu::Sane;
use Catmandu::Fix qw(publication_to_dc);
use Dancer qw(:syntax);
use DateTime;
use XML::RSS;
use Encode;
use LibreCat::App::Helper;

sub feed {
    my $period = shift // 'weekly';

    my $fixer = Catmandu::Fix->new(fixes => ['fixes/to_dc.fix']);

    my $now;

    if ($period eq 'daily') {
        $now = DateTime->now->truncate(to => 'day');
    }
    elsif ($period eq 'weekly') {
        $now = DateTime->now->truncate(to => 'week');
    }
    elsif ($period eq 'monthly') {
        $now = DateTime->now->truncate(to => 'month');
    }
    else {
        $period = 'weekly';
        $now = DateTime->now->truncate(to => 'week');
    }

    my $query = [
        "status exact public",
        "date_updated>" . $now->strftime('"%FT%H:%M:00Z"')
    ];

    my $rss = XML::RSS->new;

    $rss->channel(
        link  => h->host,
        title => h->config->{app},
        syn   => {
            updatePeriod    => $period,
            updateFrequency => "1",
            updateBase      => "2000-01-01T00:00+00:00",
        }
    );

    my $hits = h->search_publication({ q => $query });
    $hits->each(
        sub {
            my $hit = $_[0];

            if ($hit->{_id} && $hit->{citation}->{apa}) {
                $rss->add_item(
                    link  => h->host . "/publication/$hit->{_id}",
                    title => $hit->{citation}->{apa},
                    dc    => $fixer->fix($hit)->{dc},
                );
            }
        }
    );

    content_type 'xhtml';
    return $rss->as_string;
}

get '/feed' => sub {
    return feed();
};

get '/feed/:period' => sub {
    my $period = param('period');
    return feed($period);
};

1;
