package Locale::Maketext::Lexicon::CatmanduConfig;

use Catmandu::Sane;
use Catmandu;

sub parse {
    my ($self, $key) = @_;
    my $hash = Catmandu->config->{i18n}{locale}{$key};
    use Data::Dumper;
    say Dumper({$key => $hash});
    $hash;
}

1;
