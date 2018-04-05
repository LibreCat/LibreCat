package LibreCat::Types;

use Catmandu::Sane;
use Types::Standard qw(CycleTuple Str Any);
use Type::Utils -all;
use Type::Library
   -base,
   -declare => qw(Pairs);

declare Pairs, as CycleTuple[Str, Any], where { scalar(@$_) % 2 == 0 };

1;
