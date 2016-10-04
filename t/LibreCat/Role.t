use Catmandu::Sane;
use Test::More;
use Test::Exception;
use LibreCat::Role;

throws_ok { LibreCat::Role->new } qr/required/;

done_testing;

1;


