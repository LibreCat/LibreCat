use strict;
use warnings FATAL => 'all';
use Test::More;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::CLI';
    use_ok $pkg;
}

require_ok $pkg;

{

    package Catmandu::Fix::thisFixThrowsAnError;

    use Catmandu::Sane;
    use Moo;

    sub fix {Catmandu::FixError->throw("bad boy");}
}

{
    foreach my $cmd (('', 'help', '--help', '-h')) {
        my $result = test_app(qq|LibreCat::CLI| => [$cmd]);
        ok !$result->error, 'ok threw no exception';
        like $result->stdout, qr/Available commands/, 'displays help page';
    }
}

done_testing;
