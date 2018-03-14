use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use LibreCat::App::Helper;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::add_doi';
    use_ok $pkg;
}

require_ok $pkg;

is_deeply $pkg->new()->fix({foo => 'bar'}), {foo => 'bar'};

h->config->{doi} = {prefix => '10.001/test'};

is_deeply $pkg->new()->fix({_id => 'bar'}),
    {_id => 'bar', doi => '10.001/test/bar'};

done_testing;
