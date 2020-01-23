use Catmandu::Sane;
use LibreCat -self => -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use File::Slurp;

my $pkg;

BEGIN {
    $pkg = "LibreCat::Validator";
    use_ok $pkg;
}

require_ok $pkg;

{

    package T::Validator;
    use Moo;

    with $pkg;

    sub validate_data { }
}

{
    my $x = T::Validator->new(namespace => "validator.t.errors");
    can_ok $x, $_ for qw(whitelist validate_data last_errors);

    is_deeply $x->whitelist, [], "default white list";
}

done_testing;
