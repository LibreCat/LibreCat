use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::wos';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok { $x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

{
    my $pub = $x->fetch(path('t/records/journal_article.txt')->slurp);

    ok $pub , 'got a publication';

    is $pub->{title} , 'Performance ratio study based on a device simulation of a 2D monolithic interconnected Cu(In,Ga)(Se,S)(2) solar cell' , 'got a title';
    is $pub->{type} , 'journal_article', 'type == journal_article';
}

done_testing;
