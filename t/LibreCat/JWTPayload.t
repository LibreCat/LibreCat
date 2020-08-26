use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::JWTPayload';
    use_ok $pkg;
};

require_ok $pkg;

my $t;
lives_ok(sub{
    $t = $pkg->new()
});

can_ok $t, $_ for qw(encode decode add get each);

# add
my $payload = $t->add( { user => "test", role => "reviewer" } );

is(
    $payload,
    undef,
    "add: no custom attributes allowed in payload"
);

like(
    $t->last_errors->[0],
    qr/properties\snot\sallowed/,
    "add: no custom attributes allowed in payload"
);
like(
    $t->last_errors->[0],
    qr/(role|user)/,
    "add: no custom attributes allowed in payload: role, user"
);

$payload = $t->add( {} );

ok( is_hash_ref( $payload ), "add: correct payload returns payload" );
is( $t->last_errors, undef , "add: correct payload returns no errors" );

$payload = $t->add( { model => "rubbish" } );

is( $payload, undef, "add: attribute model is restricted to existing model names" );
like(
    $t->last_errors->[0],
    qr/allowed\svalues\sfor\smodel/,
    "add: attribute model is restricted to existing model names"
);
like(
    $t->last_errors->[0],
    qr/(publication|department|research_group|user|project)/,
    "add: attribute model is restricted to existing model names"
);

$payload = $t->add( { cql => "status=new" } );

is( $payload, undef, "add: model is required when attribute cql is given" );
is(
    $t->last_errors->[0],
    "model is required",
    "add: model is required when attribute cql is given"
);

$payload = $t->add( { "model" => "publication", cql => "myattr=none" } );

is( $payload, undef, "add: invalid cql for model" );
like(
    $t->last_errors->[0],
    qr/cql does not match pattern/,
    "add: invalid cql for model"
);

$payload = $t->add( { model => "publication", cql => "status=new" } );
ok( is_hash_ref( $payload ), "add: valid payload given" );

# get

my $old_payload = $t->get( $payload->{_id} );
is_deeply( $old_payload, $payload );

# encode

my $jwt;

lives_ok(sub{ $jwt = $t->encode( $payload ); });
ok( is_string($jwt) );

# decode
is_deeply(
    $t->decode( $jwt ),
    $payload
);

$jwt = $t->encode( $t->add( { exp => time - 100 } ) );

is( $t->decode( $jwt, validate => 1 ) , undef, "decode: does not return payload for expired tokens when option validate is set to true" );

ok( is_hash_ref( $t->decode( $jwt, validate => 0 ) ), "decode: does return payload for expired token when option validate is set to false" );

$jwt = $t->encode( $t->add( { nbf => time + 1800 } ) );

is( $t->decode( $jwt, validate => 1 ), undef, "decode: does not return payload for tokens that are not yet to be used when option validate is set to true" );

ok( is_hash_ref( $t->decode( $jwt, validate => 0 ) ), "decode: does return payload for tokens that are not yet to be used when option validate is set to false" );

$jwt = $t->encode( $t->add( {} ) );

lives_ok(sub {

    $t->bag()->delete_all();

}, "revoke all tokens" );

is( $t->decode( $jwt, validate => 1 ), undef, "decode: does not return payload for revoken tokens" );
ok( is_hash_ref( $t->decode( $jwt, validate => 0 ) ), "decode: does return payload for revoked tokens when option validate is set to false" );

done_testing;
