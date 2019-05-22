use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'Mojolicious::Plugin::LibreCat::Api';
    use_ok $pkg;
};

require_ok $pkg;

done_testing;
