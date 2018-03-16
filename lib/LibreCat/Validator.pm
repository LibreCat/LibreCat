package LibreCat::Validator;

use Catmandu::Sane;
use Moo::Role;

with 'Catmandu::Validator';

sub white_list {
    return ();
}

1;
