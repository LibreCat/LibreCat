use strict;
use warnings FATAL => 'all';
use lib qw(./lib ./controller);
use Catmandu;

use Test::More;
use Test::TCP;
use Test::Exception;
use Test::WWW::Mechanize;

use File::Slurp;
use IO::File;
use File::Path qw(remove_tree);
use Data::Dumper;

1;
