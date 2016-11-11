package LibreCat::Hook::foo;

use Moo;

sub fix {
    my ($self,$data) = @_;

    $data->{test} = 'before';

    $data;
}

package LibreCat::Hook::bar;

use Moo;

sub fix {
    my ($self,$data) = @_;

    $data->{test} = 'after';

    $data;
}

package main;

use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat qw(:load);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Hook';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok {$pkg->new()} 'lives_ok';

Catmandu->config->{hooks} = {
        'test-123' => {
            'before_fixes' => [qw(foo)] ,
            'after_fixes'  => [qw(bar)] ,
        }
};

my $hook = LibreCat->hook('test-123');

ok $hook , 'got a hook';

my $data = {};

ok $hook->fix_before($data) , 'fix_before';

is $data->{test} , 'before' , 'executed LibreCat::Fix::foo';

ok $hook->fix_after($data) , 'fix_after';

is $data->{test} , 'after' , 'executed LibreCat::Fix::foo';

$data = {};

ok $hook->fix_around($data, sub { $_[0]->{bla} = 'ok' ; $_[0] }) , 'fix_around';

is $data->{bla}  , 'ok'    , 'executed the around';
is $data->{test} , 'after' , 'executed LibreCat::Fix::foo';

done_testing;
