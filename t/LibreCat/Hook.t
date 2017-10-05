package main;

use strict;
use warnings FATAL => "all";
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);

package LibreCat::Hook::foo;

use Moo;

sub fix {
    my ($self, $data) = @_;

    $data->{test} = 'before';

    $data;
}

package LibreCat::Hook::bar;

use Moo;

sub fix {
    my ($self, $data) = @_;

    $data->{test} = 'after';

    $data;
}

package main;

use Catmandu::Sane;
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Hook';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok {$pkg->new()} 'lives_ok';

subtest 'basic' => sub {
    Catmandu->config->{hooks} = {
    'test-123' => {'before_fixes' => [qw(foo)], 'after_fixes' => [qw(bar)],}
    };

    my $hook = LibreCat->hook('test-123');
    ok $hook , 'got a hook';

    my $data = {};
    ok $hook->fix_before($data), 'fix_before';
    is $data->{test}, 'before', 'executed LibreCat::Fix::foo';

    ok $hook->fix_after($data), 'fix_after';
    is $data->{test}, 'after', 'executed LibreCat::Fix::foo';

    $data = {};
    ok $hook->fix_around($data, sub {$_[0]->{bla} = 'ok'; $_[0]}), 'fix_around';
    is $data->{bla},  'ok',    'executed the around';
    is $data->{test}, 'after', 'executed LibreCat::Fix::foo';

    $data = {};
    ok $hook->fix_around($data), 'fix around for empty sub';
};

subtest "hooks can be fix files" => sub {
    Catmandu->config->{hooks} = {
        'test-fix-files' => {
            'before_fixes' => [qw(test_before.fix)],
            'after_fixes' => [qw(test_after.fix)],
        }
    };

    my $hook = LibreCat->hook('test-fix-files');
    ok $hook , 'got a hook';

    my $data = {};
    ok $hook->fix_before($data), 'fix_before';
    is $data->{fixfile}, 'before', 'executed test_before.fix';

    ok $hook->fix_after($data), 'fix_after';
    is $data->{fixfile}, 'after', 'executed test_after.fix';

    $data = {};
    ok $hook->fix_around($data, sub {$_[0]->{bla} = 'ok'; $_[0]}), 'fix_around';
    is $data->{bla},  'ok',    'executed the around';
    is $data->{fixfile}, 'after', 'executed correctly';
};

subtest "default hooks" => sub {
    Catmandu->config->{hooks} = {
        'test-default_hooks' => {
            'default_before_fixes' => ["remove_field(before)"],
            'default_after_fixes' => ["remove_field(after)"],
            'before_fixes' => ["add_field(before, here)", "add_field(stay, here)"],
            'after_fixes' => ["add_field(after, here)"],
        }
    };

    my $hook = LibreCat->hook('test-default_hooks');
    ok $hook , 'got a hook';

    my $data = {};
    ok $hook->fix_before($data), 'fix_before';
    is_deeply $data, {stay => 'here'}, 'executed fix_before method';

    ok $hook->fix_after($data), 'fix_after';
    is_deeply $data, {stay => 'here', after => 'here'}, 'executed fix_after method';

    $data = {};
    ok $hook->fix_around($data, sub {$_[0]->{bla} = 'ok'; $_[0]}), 'fix_around';
    is_deeply $data, {bla => 'ok', stay => 'here', after => 'here'};
};

done_testing;
