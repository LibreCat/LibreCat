use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Hook::new_research_data_email';
    use_ok $pkg;
}
require_ok $pkg;

my $x;
lives_ok {$x = $pkg->new()} 'lives_ok';

can_ok $x, 'fix';

my $data = {type => 'research_data', status => 'submitted', year => '2017'};

ok $x->fix($data);

done_testing;
