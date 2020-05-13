use Catmandu::Sane;
use Catmandu::Util qw(:is);
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

dies_ok(sub { $pkg->new(); }, "required arguments missing");
dies_ok(sub { $pkg->new(secret => "secr3t") }, "required arguments missing");

my $t;
lives_ok(sub{
    $t = $pkg->new(
        secret => "secr3t",
        librecat => LibreCat->instance
    )
});

can_ok $t, $_ for qw(encode decode);

#encode
my($jwt,@errors) = $t->encode( { user => "test", role => "reviewer" } );

is(
    $jwt,
    undef,
    "encode: no custom attributes allowed in payload"
);

like(
    $errors[0],
    qr/properties\snot\sallowed/,
    "encode: no custom attributes allowed in payload"
);
like(
    $errors[0],
    qr/(role|user)/,
    "encode: no custom attributes allowed in payload: role, user"
);

($jwt,@errors) = $t->encode( {} );

ok( is_string( $jwt ), "encode: incorrect payload returns no payload" );
ok( scalar( @errors ) == 0, "encode: incorrect payload returns errors" );

($jwt,@errors) = $t->encode( { model => "rubbish" } );

ok( !is_string( $jwt ), "encode: attribute model is restricted to existing model names" );
like(
    $errors[0],
    qr/allowed\svalues\sfor\smodel/,
    "encode: attribute model is restricted to existing model names"
);
like(
    $errors[0],
    qr/(publication|department|research_group|user|project)/,
    "encode: attribute model is restricted to existing model names"
);

($jwt,@errors) = $t->encode( { cql => "status=new" } );

ok( !is_string($jwt), "encode: model is required when attribute cql is given" );
is(
    $errors[0],
    "model is required",
    "encode: model is required when attribute cql is given"
);

($jwt,@errors) = $t->encode( { "model" => "publication", cql => "myattr=none" } );

ok( !is_string($jwt), "encode: invalid cql for model" );
is(
    $errors[0],
    "unable to parse cql query 'myattr=none' for model 'publication'",
    "encode: invalid cql for model"
);

($jwt,@errors) = $t->encode( { model => "publication", cql => "status=new" } );
ok( is_string( $jwt ), "valid payload given" );

#decode
($jwt,@errors) = $t->encode( { exp => time - 100 } );

is( $t->decode( $jwt ) , undef, "decode: does not return payload for expired tokens" );

($jwt,@errors) = $t->encode( { nbf => time + 1800 } );

is( $t->decode( $jwt ), undef, "decode: does not return payload for tokens that are not yet to be used" );

($jwt,@errors) = $t->encode( {} );

ok( is_hash_ref( $t->decode( $jwt ) ), "decode: return payload  as hash reference" );

lives_ok(sub {

    $t->bag()->delete_all();

}, "revoke all tokens" );

is( $t->decode( $jwt ), undef, "decode: does not return payload for revoken tokens" );

done_testing;
