use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::file_date_updated';
    use_ok $pkg;
};

require_ok $pkg;

is_deeply $pkg->new()->fix({ foo => 'bar'}), { foo => 'bar' };

is_deeply $pkg->new()->fix({
                file => [
                    { date_updated => '1970-01-01T00:00:00Z' } ,
                    { date_updated => '2050-01-01T00:00:00Z' } ,
                ]
            }),
            {
                file => [
                    { date_updated => '1970-01-01T00:00:00Z' } ,
                    { date_updated => '2050-01-01T00:00:00Z' } ,
                ],
                file_date_updated => '2050-01-01T00:00:00Z'
            };

done_testing;
