use Test::Lib;
use TestHeader;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::ImageResizer';
    use_ok $pkg;
}
require_ok $pkg;

my $opts = {package => 'Simple', options => {root => './t'}};

dies_ok {$pkg->new()} 'die ok: no args';
dies_ok {$pkg->new(files => $opts)} 'die ok: missing args';
dies_ok {$pkg->new(access => $opts)} 'die ok: missing args';
lives_ok {$pkg->new(files => $opts, access => $opts)}
'lives ok: required args';

my $resizer = $pkg->new(files => $opts, access => $opts);
can_ok $resizer, 'work';

lives_ok {
    $resizer->work({key => 1})
}
"Calling work is safe.";

done_testing;
