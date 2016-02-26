use strict;
use warnings;
use Test::More;
use Test::Exception;

my $pkg;
BEGIN {
    $pkg = 'LibreCat::Worker::DataCite';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok { $pkg->new(user => 'test', password => 'test') };
dies_ok { $pkg->new(user => 'test') };
dies_ok { $pkg->new(password => 'test') };

my $datacite = $pkg->new(user => '', password => '', test_mode => 1);
#my $status = $datacite->mint(doi => '10.5072/librecat', landing_url => "http://librecat.org");
#print $status;
#is $status, '201';

done_testing;
