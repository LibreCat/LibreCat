package LibreCat::Validator;

use Catmandu::Sane;
use Moo::Role;

with 'Catmandu::Validator';

has whitelist => (is => 'lazy');

sub _build_whitelist {
    [];
}

1;
