package LibreCat::Cmd::sitemap;

use Catmandu::Sane;
use Catmandu::Util qw(io join_path);
use Catmandu;
use Carp;
use POSIX qw(strftime);
use parent 'LibreCat::Cmd';

sub description {
    return <<EOF;
Usage:

librecat sitemap [-v] <DIRECTORY>

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (['v', ""],);
}

sub command {
    my ($self, $opts, $args) = @_;

    croak "usage: $0 sitemap <DIRECTORY>" unless (@$args);

    my $dir = shift @$args;

    my $config = Catmandu->config;
    my $bag    = Catmandu->store('search')->bag('publication');
    my $today  = strftime "%Y-%m-%d", gmtime;
    my $n      = 0;

    $bag->select(sub {$_[0]->{status} && $_[0]->{status} eq 'public'})
        ->group(10000)->each(
        sub {
            my $group = $_[0];
            $n++;

            my $path = join_path($dir, sprintf("sitemap-%05d.xml", $n));
            my $file = io($path, mode => 'w');

            $file->say('<?xml version="1.0" encoding="UTF-8"?>');
            $file->say(
                '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
            );
            $group->each(
                sub {
                    my $rec = $_[0];
                    my $loc = "$config->{uri_base}/record/$rec->{_id}";
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
            print STDERR "Generating $path\n" if $opts->{v};
        }
        );

    my $path = join_path($dir, "siteindex.xml");
    my $file = io($path, mode => 'w');
    $file->say('<?xml version="1.0" encoding="UTF-8"?>');
    $file->say(
        '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    for my $i (1 .. $n) {
        my $loc = sprintf("$config->{uri_base}/sitemap-%05d.xml", $i);
        $file->say("<sitemap><url><loc>$loc</loc><lastmod>$today</lastmod></url></sitemap>");
    }
    $file->say('</sitemapindex>');
    $file->close;
    print STDERR "Generating $path\n" if $opts->{v};

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::sitemap - generate siteindex and sitemaps

=head1 SYNOPSIS

    librecat sitemap [-v] <DIRECTORY>

=cut
