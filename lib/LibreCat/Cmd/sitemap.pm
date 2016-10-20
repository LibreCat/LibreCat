package LibreCat::Cmd::sitemap;

use Catmandu::Sane;
use Catmandu::Util qw(io join_path);
use Catmandu;
use POSIX qw(strftime);
use parent 'LibreCat::Cmd';

sub command_opt_spec {
    (["dir=s", "", {required => 1}],);
}

sub command {
    my ($self, $opts, $args) = @_;

    my $config = Catmandu->config;
    my $bag    = Catmandu->store('search')->bag('publication');
    my $today  = strftime "%Y-%m-%d", gmtime;
    my $n      = 0;

    $bag->select(sub {$_[0]->{status} && $_[0]->{status} eq 'public'})
        ->group(10000)->each(
        sub {
            my $group = $_[0];
            $n++;

            my $path = join_path($opts->dir, sprintf("sitemap-%05d.xml", $n));
            my $file = io($path, mode => 'w');

            $file->say('<?xml version="1.0" encoding="UTF-8"?>');
            $file->say(
                '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
            );
            $group->each(
                sub {
                    my $rec = $_[0];
                    my $type
                        = $rec->{type} eq 'research_data'
                        ? 'data'
                        : 'publication';
                    my $loc = "$config->{host}/$type/$rec->{_id}";
                    my $mod = substr(
                        $rec->{date_updated}
                            || $rec->{date_created}
                            || $today,
                        0, 10
                    );
                    $file->say(
                        "<url><loc>$loc</loc><lastmod>$mod</lastmod><priority>0.9</priority></url>"
                    );
                }
            );
            $file->say('</urlset>');
            $file->close;
        }
        );

    my $file = io(join_path($opts->dir, "siteindex.xml"), mode => 'w');
    $file->say('<?xml version="1.0" encoding="UTF-8"?>');
    $file->say(
        '<sitemap xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    for my $i (1 .. $n) {
        my $loc = sprintf("$config->{host}/sitemap-%05d.xml", $i);
        $file->say("<url><loc>$loc</loc><lastmod>$today</lastmod></url>");
    }
    $file->say('</sitemap>');
    $file->close;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::sitemap - generate siteindex and sitemaps

=cut
