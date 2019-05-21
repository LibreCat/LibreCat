use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Token';
    use_ok $pkg;
};

require_ok $pkg;

dies_ok {$pkg->new()} "'secret' missing";
lives_ok {$pkg->new(secret => "secr3t")};

my $t =$pkg->new(secret => "secr3t");

can_ok $t, $_ for qw(encode decode);

my $payload = {user => "test", role => "reviewer"};

my $jwt = $t->encode($payload);
ok $jwt, "web token encoded";
ok length $jwt > 40, "long encoding string";

is_deeply $t->decode($jwt), $payload, "same data after decoding";

done_testing;
