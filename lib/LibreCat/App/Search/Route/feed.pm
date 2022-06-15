package LibreCat::App::Search::Route::feed;

=head1 NAME

LibreCat::App::Search::Route::feed - provides routes for RSS feeds

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Catmandu::Fix qw(publication_to_dc);
use Dancer qw(:syntax);
use DateTime;
use XML::RSS;
use Encode;
use LibreCat::App::Helper;
use LibreCat qw(searcher);

sub feed {
    my $q = shift;
    my $period = shift // 'weekly';

    state $fixer = h->create_fixer('to_dc.fix');

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
    unshift @$query, $q if is_string($q);

    my $rss      = XML::RSS->new;
    my $uri_base = h->uri_base();
    $rss->channel(
        link  => $uri_base,
        title => h->config->{app},
        syn   => {
            updatePeriod    => $period,
            updateFrequency => "1",
            updateBase      => "2000-01-01T00:00+00:00",
        }
    );

    my $hits = searcher->search('publication', {cql => $query});

    $hits->each(
        sub {
            my $hit   = $_[0];
            my $title = $hit->{title} // 'no title';

            $rss->add_item(
                link  => $uri_base . "/record/$hit->{_id}",
                title => $title,
                dc    => $fixer->fix($hit)->{dc},
            );
        }
    );

    content_type 'xhtml';
    return $rss->as_string;
}

=head2 GET /feed

E.g to retrieve a researcher's publication feed go to

/feed?q=person=1234

=cut

get '/feed' => sub {
    return feed(params("query")->{q});
};

=head2 GET /feed/:period

E.g to retrieve a researcher's publication feed fromt last month go to

/feed/monthly?q=person=1234

Other possible values for :period are 'daily' and 'weekly'.

=cut

get '/feed/:period' => sub {
    my $period = params("route")->{period};
    return feed(params("query")->{q}, $period);
};

1;
