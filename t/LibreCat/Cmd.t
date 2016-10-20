use strict;
use warnings FATAL => 'all';
use Test::More;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd';
    use_ok $pkg;
}

require_ok $pkg;

use LibreCat::CLI;

my $result = test_app(qq|LibreCat::CLI| => [qw()]);

like $result->stdout, qr/help:/, 'printed what we expected';
is $result->error,    undef,     'threw no exceptions';
is $result->stderr,   '',        'nothing sent to sderr';

$result = test_app('LibreCat::CLI' => [qw(help)]);

like $result->stdout, qr/commands:/, 'printed what we expected';
is $result->error,    undef,         'threw no exceptions';
is $result->stderr,   '',            'nothing sent to sderr';

$result = test_app('LibreCat::CLI' => [qw(-h)]);

like $result->stdout, qr/commands:/, 'printed what we expected';
is $result->error,    undef,         'threw no exceptions';
is $result->stderr,   '',            'nothing sent to sderr';

$result = test_app('LibreCat::CLI' => [qw(--help)]);

like $result->stdout, qr/commands:/, 'printed what we expected';
is $result->error,    undef,         'threw no exceptions';
is $result->stderr,   '',            'nothing sent to sderr';

done_testing;
