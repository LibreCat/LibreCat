use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use Role::Tiny;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Logger';
    use_ok $pkg;
}

require_ok $pkg;

{

    package T::Logger;
    use Moo;

    with $pkg;
}

my $l = T::Logger->new;

ok $l->does('LibreCat::Logger');
can_ok($l, 'log');
isa_ok($l->log,          'Log::Any::Proxy');
isa_ok($l->log->adapter, 'Log::Any::Adapter::Log4perl');
ok($l->log->is_debug);

done_testing;
