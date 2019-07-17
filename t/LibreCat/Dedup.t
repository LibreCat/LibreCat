use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Dedup';
    use_ok $pkg;
};

require_ok $pkg;

{
    package T::Dedup;
    use Moo;
    with $pkg;

    sub _find_duplicate {
        return [1234,9876];
    }
}

lives_ok {T::Dedup->new()};

my $d = T::Dedup->new;
can_ok $d, $_ for qw(has_duplicate find_duplicate);

done_testing;
