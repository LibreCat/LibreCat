use strict;
use warnings;
use Test::More;
use Catmandu;

Catmandu->load(':up');
my $conf = Catmandu->config;

is (ref $conf, 'HASH', "config hash");
is ($conf->{session}, 'Catmandu', "config key ok");
is (defined $conf->{store}, 1, "config for store ok");
is (defined $conf->{importer}, 1, "config for importer ok");

done_testing;
