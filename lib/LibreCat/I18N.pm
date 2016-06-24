package LibreCat::I18N::_Handle;

use Catmandu::Sane;
use Catmandu;
use parent 'Locale::Maketext';
use Locale::Maketext::Lexicon Catmandu->config->{i18n}{lexicon};

package LibreCat::I18N;

use Catmandu::Sane;
use Moo;

has locale => (is => 'ro', required => 1);
has _handle => (is => 'lazy', handles => {localize => 'maketext'});

sub _build__handle {
    my ($self) = @_;
    LibreCat::I18N::_Handle->get_handle($self->locale);
}

1;

__END__

=pod

=head1 NAME

LibreCat::I18N - localizaton class

=head1 SYNOPSIS

    # lexicon entries can be any that Locale::Maketext::Lexicon understands
    Catmandu->config->{i18n}{lexicon} = {
        de => ['CatmanduConfig', ['de']],
        fr => [
            Gettext => 'hello_fr.po',
            Gettext => 'local/hello/fr.po',
        ],
        en => ['CSV', 'en.csv'],
    };

    my $i18n = LibreCat::I18N->new(locale => 'de');
    my $hallo = $i18n->localize('hello');

=cut
