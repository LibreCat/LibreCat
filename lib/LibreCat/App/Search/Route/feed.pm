package LibreCat::App::Search::Route::feed;

=head1 NAME

LibreCat::App::Search::Route::feed - provides routes for RSS feeds

=cut

use Catmandu::Sane;
use Catmandu::Fix qw(publication_to_dc);
use Dancer qw(:syntax);
use DateTime;
use XML::RSS;
use Encode;
use LibreCat::App::Helper;
use LibreCat qw(searcher);

sub feed {
    my $q      = shift // [];
    my $period = shift // 'weekly';

    state $fixer = Catmandu::Fix->new(fixes => ['fixes/to_dc.fix']);

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
        @$q,
        "status exact public",
        "date_updated>" . $now->strftime('"%FT%H:%M:00Z"')
    ];

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

    my $hits = searcher->search('publication', {q => $query});

    $hits->each(
        sub {
            my $hit = $_[0];
            my $title = $hit->{title} // 'no title';

            $rss->add_item(
                link  => $uri_base . "/publication/$hit->{_id}",
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
    my $param = h->extract_params;
    return feed($param->{q});
};

=head2 GET /feed/:period

E.g to retrieve a researcher's publication feed fromt last month go to

/feed/monthly?q=person=1234

Other possible values for :period are 'daily' and 'weekly'.

=cut

get '/feed/:period' => sub {
    my $param  = h->extract_params;
    my $period = param('period');
    return feed($param->{q}, $period);
};

1;
