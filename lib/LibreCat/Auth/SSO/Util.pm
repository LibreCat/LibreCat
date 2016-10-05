package LibreCat::Auth::SSO::Util;

use Catmandu::Sane;
use Catmandu::Util qw(is_string);
use URI::Escape qw(uri_escape);
use namespace::clean;
use Exporter qw(import);

my @uri = qw(uri_for);
our @EXPORT_OK = (@uri);
our %EXPORT_TAGS = (all => [@EXPORT_OK], uri => [@uri]);

sub uri_for {
    my ($env, $path, $params) = @_;

    my $url = _scheme_for($env) . "://" . _host_for($env) . $path;

    if ($params) {

        $url .= "?" . _construct_query($params);

    }

    $url;
}

sub _host_for {
    my $env = $_[0];
    $env->{X_FORWARDED_HOST}
        || $env->{HTTP_X_FORWARDED_HOST}
        || $env->{HTTP_HOST};
}

sub _scheme_for {
    my $env = $_[0];
           $env->{'X_FORWARDED_PROTOCOL'}
        || $env->{'HTTP_X_FORWARDED_PROTOCOL'}
        || $env->{'HTTP_FORWARDED_PROTO'}
        || $env->{'psgi.url_scheme'}
        || $env->{'PSGI.URL_SCHEME'};
}

sub _construct_query {
    my $data  = shift;
    my @parts = ();
    for my $key (keys %$data) {

        if (is_array_ref($data->{$key})) {

            for my $val (@{$data->{$key}}) {

                push @parts, uri_escape($key) . "=" . uri_escape($val // "");

            }

        }
        else {

            push @parts,
                uri_escape($key) . "=" . uri_escape($data->{$key} // "");

        }
    }
    join("&", @parts);
}

1;
