use strict;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use Test::TCP;
use HTTPServer;
use Path::Tiny;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::Datacite';
    use_ok $pkg;
}

require_ok $pkg;

dies_ok { $pkg->new() } "missing user/password";
dies_ok { $pkg->new(user => 'me') } "missing password";
dies_ok { $pkg->new(password => 'secret') } "missing user";
lives_ok { $pkg->new(user => 'me', password => 'secret') }
"object lives with user/password";

my $datacite = $pkg->new(user => 'me', password => 'secret', test_mode => 1);

can_ok $datacite, $_ for qw(work mint metadata);

done_testing;
