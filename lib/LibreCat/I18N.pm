package LibreCat::I18N::Handle;

use Catmandu::Sane;
use Catmandu;
use parent 'Locale::Maketext';
use Locale::Maketext::Lexicon Catmandu->config->{i18n}{lexicon};

package LibreCat::I18N;

use Catmandu::Sane;
use Moo;

has locale => (is => 'ro', required => 1);
has handle => (is => 'lazy');

sub _build_handle {
    my ($self, $loc) = @_;
    LibreCat::I18N::Handle->get_handle($loc);
}

sub localize {
    my ($self, $str) = @_;
    $self->handle->maketext($str);
}

1;
