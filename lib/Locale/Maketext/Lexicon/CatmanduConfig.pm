package Locale::Maketext::Lexicon::CatmanduConfig;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Expander;

sub parse {
    my ($self, $key) = @_;
    my $hash = Catmandu->config->{locale}{$key};
    Catmandu::Expander->collapse_hash($hash);
}

1;
