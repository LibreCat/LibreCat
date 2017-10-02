use strict;
use warnings FATAL => 'all';
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use Data::Dumper;

my $pkg;
BEGIN {
    $pkg = 'LibreCat::Index';
    use_ok $pkg;
}
require_ok $pkg;

ok $pkg->initialize, "initialize indices";

like $pkg->get_status->{number_of_indices}, qr/\d/, "number of indices";

like $pkg->get_status->{active_index}, qr/librecat/, "index name";

done_testing;
