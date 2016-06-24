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

__END__

=pod

=head1 NAME

Locale::Maketext::Lexicon::CatmanduConfig - Use Catmandu config files as a Maketext lexicon

=head1 SYNOPSIS

    Catmandu->{config}{locale}{en} = {
        hello => "Hello",
    };

    package MyI18N;
    use parent 'Locale::Maketext';
    use Locale::Maketext::Lexicon {
        en => [ CatmanduConfig => ['en'] ],
    };

=cut
