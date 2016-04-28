use Test::Lib;
use LibreCatTest;

my $pkg;
BEGIN {
    $pkg = 'LibreCat::Worker::ImageResizer';
    use_ok $pkg;
}
require_ok $pkg;

my $opts = {package => 'Simple', options => {root => './t'}};

dies_ok { $pkg->new() };
dies_ok { $pkg->new(files => $opts) };
dies_ok { $pkg->new(access => $opts) };
lives_ok {$pkg->new(files => $opts, access => $opts)};

my $reziser = $pkg->new();
can_ok $resizer, 'work';

lives_ok {
    $reziser->work({from => "me@example.com", to => "you@example.com", subject => "Mail!"})
} "Calling work is safe.";

done_testing;
