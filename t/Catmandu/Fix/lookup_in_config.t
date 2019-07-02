use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::lookup_in_config';
    use_ok $pkg;
}

require_ok $pkg;

is_deeply $pkg->new("foo", "filestore")->fix({foo => 'bar'}), {foo => 'bar'};

is_deeply $pkg->new("new_field", "filestore")->fix(
    {
        new_field => "test",
        controll_field => 1,
    }
    ),
    {
        new_field => {
            "package" => "Simple",
            options => { root => "t/data2" },
        },
        controll_field => 1,
    };

done_testing;
