use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use LibreCat qw(publication);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::wos';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok {$x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

{
    my $pub = $x->fetch(path('t/records/journal_article.txt')->slurp);

    ok $pub , 'got a publication';

    $pub->[0]{_id} = 'DUMMY';

    is $pub->[0]{title},
        'Performance ratio study based on a device simulation of a 2D monolithic interconnected Cu(In,Ga)(Se,S)(2) solar cell',
        'got a title';
    is $pub->[0]{type}, 'journal_article', 'type == journal_article';

    my $is_valid = publication->is_valid($pub->[0]);

    if ($is_valid) {
        ok 1, 'record is valid';
    }
    else {
        ok 0 , 'record is valid';
        say STDERR join("\n", @{publication->validator->last_errors});
    }
    
    ok !$x->fetch('t/does_not_exist.txt'), "empty record";
}

done_testing;
