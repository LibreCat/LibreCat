use Catmandu::Sane;
use Catmandu::Importer::YAML;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use App::Cmd::Tester;
use LibreCat::CLI;
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::jwt_payload';
    use_ok $pkg;
};

require_ok $pkg;
{
    my $result = test_app(qq|LibreCat::CLI| => ['jwt_payload']);
    ok $result->error, 'missing command';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'jwt_payload']);
    ok !$result->error, 'help message for jwt_payload cmd';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
}

{
    my $stderr = <<EOF;
jwt payload not accepted:
 * allowed values for model: publication, department, research_group, user, project
jwt payload not accepted:
 * model is required
jwt payload not accepted:
 * properties not allowed: rubbish
jwt payload not accepted:
 * exp must be an integer, got string
jwt payload not accepted:
 * nbf must be an integer, got string
EOF
    my $result = test_app( qq|LibreCat::CLI| => ['jwt_payload','add','t/records/jwt-payloads-error.yml'] );
    is(
        $result->stderr,
        $stderr,
        "add: invalid records are reported on stderr"
    );
}

my $payloads;

{
    my $result = test_app( qq|LibreCat::CLI| => ['jwt_payload','add','t/records/jwt-payloads-ok.yml'] );
    lives_ok(sub {
        my $stdout = $result->stdout();
        $payloads = Catmandu::Importer::YAML->new( file => \$stdout )->to_array();
    });
    ok( ref( $payloads ) eq "ARRAY" && scalar( @$payloads ) == 7, "add: valid payloads added and exported to YAML" );
}

if( $payloads ){

    my $result = test_app( qq|LibreCat::CLI| => ['jwt_payload','export'] );
    my $exported_payloads;
    lives_ok(sub {
        my $stdout = $result->stdout();
        $exported_payloads = Catmandu::Importer::YAML->new( file => \$stdout )->to_array();
    });
    ok( ref( $exported_payloads ) eq "ARRAY" && scalar( @$exported_payloads ), "export: all payloads are exported to YAML" );

}

if( $payloads ){

    my $result = test_app( qq|LibreCat::CLI| => ['jwt_payload','get',$payloads->[0]->{_id}] );
    my $exported_payload;
    lives_ok(sub {
        my $stdout = $result->stdout();
        $exported_payload = Catmandu::Importer::YAML->new( file => \$stdout )->first;
    });
    is_deeply( $exported_payload, $payloads->[0], "get: payload exported to YAML by id" );

}

{
    my $result = test_app( qq|LibreCat::CLI| => ['jwt_payload','encode'] );
    ok( $result->error, "encode: no no payload id given" );
    is( $result->stderr, "no payload id given\n", "encode: no no payload id given" );
}

{
    my $result = test_app( qq|LibreCat::CLI| => ['jwt_payload','encode','myid'] );
    ok( $result->error, "encode: invalid payload id given" );
    is( $result->stderr, "no jwt payload for id myid\n", "encode: invalid payload id given" );
}

my $jwt;

if( $payloads ){

    my $result = test_app( qq|LibreCat::CLI| => ['jwt_payload','encode',$payloads->[0]->{_id}] );
    is( $result->exit_code, 0 );
    $jwt = $result->stdout;
    chomp($jwt);
    ok( length( $jwt ), "'jwt_payload encode' returns jwt" );

}

{
    my $result = test_app(qq|LibreCat::CLI| => ['jwt_payload','decode',$jwt]);
    my $decoded_payload;
    lives_ok(sub {
        my $stdout = $result->stdout();
        $decoded_payload = Catmandu::Importer::YAML->new( file => \$stdout )->first;
    });
    is_deeply( $decoded_payload, $payloads->[0], "decode: decoded jwt equals old payload" );
}

# cannot decode rubbish
{
    my $result = test_app(qq|LibreCat::CLI| => ['jwt_payload','decode','rubbish']);
    ok( $result->error, "decode: cannot decode syntactically invalid tokens" );
    is( $result->stderr, "unable to decode token rubbish\n", "decode: cannot decode syntactically invalid tokens" );

}

# cannot decode expired tokens
{
    my $result = test_app(qq|LibreCat::CLI| => ['jwt_payload','decode',$payloads->[0]->{_id}]);
    ok( $result->error, "decode: cannot decoded expired tokens" );
    is( $result->stderr, "unable to decode token $payloads->[0]->{_id}\n", "decode: cannot decoded expired tokens" );

}

done_testing;
