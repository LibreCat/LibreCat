package Catmandu::Fix::language;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Moo;

sub fix {
    my ($self, $pub) = @_;

    map {
        if ($_->{name} eq "English" or $_->{name} eq "German") {
            $_->{iso}
                = h->config->{lists}->{language_preselect}->{$_->{name}};
        }
        else {
            $_->{iso} = h->config->{lists}->{language}->{$_->{name}};
        }
    } @{$pub->{language}};

    if ($pub->{original_language}) {
        foreach my $lang (@{$pub->{original_language}}) {
            if ($lang->{name} eq "English" or $lang->{name} eq "German") {
                $lang->{iso} = h->config->{lists}->{language_preselect}
                    ->{$lang->{name}};
            }
            else {
                $lang->{iso}
                    = h->config->{lists}->{language}->{$lang->{name}};
            }
        }
    }

    return $pub;
}

1;
