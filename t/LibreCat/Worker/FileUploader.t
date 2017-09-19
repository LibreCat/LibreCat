use Catmandu::Sane;
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::FileUploader';
    use_ok $pkg;
}


require_ok $pkg;

my $opts = {package => 'Simple', options => {root => './t/data3'}};

dies_ok {$pkg->new()} 'die ok: no args';
lives_ok {$pkg->new(files => $opts, access => $opts)}
'lives ok: required args';

my $uploader = $pkg->new(files => $opts, access => $opts);
can_ok $uploader, 'work';

my $ret;
lives_ok {
    $ret = $uploader->work({key => 1, filename => 'README.md' , path => 'README.md'})
}
"Calling work is safe.";

is $ret , 1 , 'work returned the correct response code';

ok -r "t/data3/000/000/001/README.md" , "Found the README.md file";

unlink "t/data3/000/000/001/README.md";

done_testing;
