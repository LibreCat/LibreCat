use Catmandu::Sane;
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::ImageResizer';
    use_ok $pkg;
}

my $thumbnail_path = 't/data3/000/000/001/thumbnail.png';

require_ok $pkg;

my $opts = {package => 'Simple', options => {root => './t/data3'}};

dies_ok {$pkg->new()} 'die ok: no args';
dies_ok {$pkg->new(files => $opts)} 'die ok: missing args';
dies_ok {$pkg->new(access => $opts)} 'die ok: missing args';
lives_ok {$pkg->new(files => $opts, access => $opts)}
'lives ok: required args';

my $resizer = $pkg->new(files => $opts, access => $opts);
can_ok $resizer, 'work';

my $ret;

lives_ok {
    $ret = $resizer->work({key => 1, filename => 'publication.pdf'})
}
"Calling work is safe.";

is_deeply $ret , {ok => 1} , 'work returned the correct response code';

ok -r $thumbnail_path , "found a thumbnail";
ok -s $thumbnail_path , "thumbnail is not empty";

lives_ok {
    $ret = $resizer->work({key => 1, delete => 1})
}
"Calling work is safe.";

is $ret , 1 , 'work returned the correct response code';

ok ! -r $thumbnail_path , "thumbnail is deleted";

done_testing;
