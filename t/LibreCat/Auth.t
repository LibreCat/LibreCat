use Test::Lib;
use TestHeader;
use Role::Tiny;

my $pkg;
my @worker_pkg;

BEGIN {
    $pkg = 'LibreCat::Auth';
    use_ok $pkg;
    @worker_pkg = map {
        $_ =~ s/\.pm$//;
        'LibreCat::Auth::' . $_;
    } read_dir('lib/LibreCat/Auth/');

    use_ok $_ for @worker_pkg;
}

require_ok $pkg;

require_ok $_ for @worker_pkg;

{
#    package T::Auth;
#    use Moo;
#    with $pkg;

    package T::Auth::X;
    use Moo;
    with $pkg;

    sub _authenticate {
        my ($self, $params) = @_;
        return 1;
    }
}

my $a = T::Auth::X->new();
can_ok $a, 'authenticate';
can_ok $a, 'obfuscate_params';

#dies_ok { T::Auth->new() };
#can_ok $s, 'bags';
#can_ok $s, 'bag';

#is $a->bag_class, 'T::Auth::X';
#$s = T::Store->new(bag_class => 'T::CustomBagClass');
#is $s->bag_class, 'T::CustomBagClass';

#is $s->default_bag, 'data';

done_testing;
