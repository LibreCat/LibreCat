use strict;
use warnings;

use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat -self, -load => {layer_paths => [qw(t/layer)]};

use Test::More import => ['!pass'];
use Test::Exception;
use Test::WWW::Mechanize::PSGI;
use JSON::MaybeXS qw();
use Catmandu::Util qw();
use Catmandu::Importer::YAML;
use Try::Tiny;

sub maybe_decode_json {
    my $raw = $_[0];
    my $data;
    try {
        $data = JSON::MaybeXS->new()->utf8(1)->decode($raw);
    };
    $data;
}

sub maybe_decode_yaml {
    my $raw = $_[0];
    my $data;
    try {
        $data = Catmandu::Importer::YAML->new(
            file => \$raw
        )->first();
    };
    $data;
}

sub encode_json {
    JSON::MaybeXS->new()->utf8(1)->encode($_[0]);
}

my $app = eval {do './bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

subtest 'sru' => sub {
    $mech->get_ok('/sru');
    $mech->content_like(qr/explainResponse/);

    $mech->get_ok('sru?version=1.1&operation=searchRetrieve&query=einstein');
    $mech->content_like(qr/\<numberOfRecords\>/);
};

subtest '/oai' => sub {
    $mech->get_ok('/oai');
    $mech->content_like(qr/OAI-PMH/);

    $mech->content_like(qr/illegal OAI verb/);
    $mech->get_ok('/oai?verb=Identify');
    $mech->content_like(qr/\<repositoryName\>/);
};

subtest 'openapi' => sub {

    # /openapi.json
    $mech->get_ok('/openapi.json');

    my $data_json = maybe_decode_json( $mech->content() );

    ok( is_hash_ref( $data_json ), 'parse content /openapi.json' );

    ok( is_string( $data_json->{basePath} ), 'data from /openapi.json has /basePath' );

    # /openapi.yml
    $mech->get_ok('/openapi.yml');

    my $data_yaml = maybe_decode_yaml( $mech->content() );

    ok( is_hash_ref( $data_yaml ), 'parse content /openapi.yml' );

    ok( is_string( $data_yaml->{basePath} ), 'data from /openapi.yml has /basePath' );

};

subtest 'jsonapi' => sub{

    # clean DBs
    for my $bag (qw(publication department project research_group user)) {
        note("deleting main $bag");
        {
            my $store = Catmandu->store("main")->bag($bag);
            $store->delete_all;
            $store->commit;
        }

        note("deleting version $bag");
        {
            my $store = Catmandu->store("main")->bag("$bag\_version");
            $store->delete_all;
            $store->commit;
        }

        note("deleting search $bag");
        {
            my $store = Catmandu->store("search")->bag($bag);
            $store->delete_all;
            $store->commit;
        }
    }

    my $librecat = librecat();
    my $uri_base = $librecat->config->{uri_base};
    my $token = $librecat->token->encode({foo => "bar"});
    my $err_auth_required = {
       errors => [
          {
             title => "authorization required",
             status => "401"
          }
       ]
    };
    my $err_access_denied = {
       errors => [
          {
             title => "access denied",
             status => "403"
          }
       ]
    };

    my %headers = ( Authorization => "Bearer $token" );

    # model authentication: JWT
    {
        $mech->get( "/api/v1" );

        is( $mech->status, 401, "no header Authorization supplied: status 401" );

        is_deeply(
            maybe_decode_json( $mech->content() ),
            $err_auth_required,
            "content is error authorization required"
        );

        $mech->get( "/api/v1",Authorization => "invalid-auth" );

        is( $mech->status, 403, "header Authorization with incorrect type: status 403" );

        is_deeply(
            maybe_decode_json( $mech->content() ),
            $err_access_denied,
            "content is error access denied"
        );

        $mech->get( "/api/v1", Authorization => $token );

        is( $mech->status, 403, "header Authorization with correct token, but without type Bearer: status 403" );

        $mech->get( "/api/v1", %headers );

        #catch all route returns a 404
        is( $mech->status, 404, "authentication ok, but record not found" );

        is_deeply(
            maybe_decode_json( $mech->content() ),
            {
               errors => [
                  {
                     title => "route not found",
                     status => "404"
                  }
               ]
            },
            "content is error not found"
        );

    }

    # model user
    {
        # GET /api/v1/user/:id

        my $model = $librecat->model( "user" );

        $mech->get( "/api/v1/user/njfranck", %headers );

        is( $mech->status(), 404, "GET /api/v1/user/:id -> status 404" );

        $model->add({
            _id         => "njfranck",
            login       => "njfranck",
            password    => '$2a$08$p1zhJInkNqy9nvMFsEPde./hU4ERNQuX2UQUjZA/ddrp1uUXikn/6',
            super_admin => 1,
            account_status => "active",
            full_name => "Nicolas Franck",
            first_name => "Nicolas",
            last_name => "Franck"
        });

        my $test_user = $model->get( "njfranck" );

        $mech->get( "/api/v1/user/njfranck", %headers );

        is( $mech->status(), 200, "GET /api/v1/user/:id -> status 200" );

        is_deeply(
            maybe_decode_json( $mech->content() ),
            {
                data => {
                    id => $test_user->{_id},
                    type => "user",
                    attributes => $test_user,
                    links => {
                        self => "${uri_base}/api/v1/user/njfranck"
                    }
                }
            },
            "GET /api/v1/user/:id -> response body ok"
        );

        # PUT /api/v1/user/:id
        $test_user->{account_status} = "inactive";

        $mech->put(
            "/api/v1/user/njfranck",
            %headers,
            Content => encode_json( $test_user )
        );

        is( $mech->status(), 200, "PUT /api/v1/user/:id -> status 200" );

        $test_user = $model->get("njfranck"); #get updated user

        is_deeply(
            maybe_decode_json( $mech->content ),
            {
                data => {
                    id => $test_user->{_id},
                    type => "user",
                    attributes => $test_user,
                    links => {
                        self => "${uri_base}/api/v1/user/njfranck"
                    }
                }
            },
            "PUT /api/v1/user/:id -> response body ok"
        );

        # PATCH /api/v1/user/:id
        $mech->patch(
            "/api/v1/user/njfranck",
            %headers,
            Content => encode_json({ account_status => "active" })
        );

        is( $mech->status(), 200, "PATCH /api/v1/user/:id -> status 200" );

        $test_user = $model->get("njfranck"); #get updated user

        is_deeply(
            maybe_decode_json( $mech->content ),
            {
                data => {
                    id => $test_user->{_id},
                    type => "user",
                    attributes => $test_user,
                    links => {
                        self => "${uri_base}/api/v1/user/njfranck"
                    }
                }
            },
            "PATCH /api/v1/user/:id -> response body ok"
        );

        # POST /api/v1/user
        $mech->post(
            "/api/v1/user",
            %headers,
            Content => encode_json({
                account_status => "active",
                first_name => "Patrick"
            })
        );

        is( $mech->status(), 400, "POST /api/v1/user -> status 400" );

        is_deeply(
            maybe_decode_json( $mech->content ),
            {
                errors => [
                    {
                        title => "last_name is required",
                        code => "object.required",
                        source => {
                            pointer => "/last_name"
                        },
                        status => "400"
                    }
                ]
            },
            "POST /api/v1/user -> response body ok"
        );

        $mech->post(
            "/api/v1/user",
            %headers,
            Content => encode_json({
                _id => "phochste",
                account_status => "active",
                first_name => "Patrick",
                last_name => "Hochstenbach"
            })
        );

        is( $mech->status(), 201, "POST /api/v1/user -> status 201" );

        $test_user = $model->get( "phochste" );

        is_deeply(
            maybe_decode_json( $mech->content ),
            {
                data => {
                    id => $test_user->{_id},
                    type => "user",
                    attributes => $test_user,
                    links => {
                        self => "${uri_base}/api/v1/user/".$test_user->{_id}
                    }
                }
            },
            "POST /api/v1/user -> response body ok"
        );

        my $versioning_enabled = $model->does("LibreCat::Model::Plugin::Versioning");

        # GET /api/v1/user/:id/versions
        $mech->get( "/api/v1/user/njfranck/versions", %headers );

        if( $versioning_enabled ){

        }
        else {

            is( $mech->status, 400, "GET /api/v1/user/:id/versions -> status 400" );

            is_deeply(
                maybe_decode_json( $mech->content ),
                {
                    errors => [
                      {
                          title => "no versioning is enabled for model user",
                          status => "400"
                      }
                    ]
                },
                "GET /api/v1/user/:id/versions -> not supported"
            );

        }

    }

    # model publication: specific tests for this type of model -> versioning and file
    {
        # GET /api/v1/publication/:id/versions

        my $model = $librecat->model( "publication" );

        $model->add({
            _id     => 1,
            type    => "book",
            status  => "new",
            title   => "my little pony"
        });

        my $test_record = $model->get( 1 );

        $mech->get( "/api/v1/publication/1/versions", %headers );

        is( $mech->status, 200, "GET /api/v1/publication/:id/versions -> status 200" );

        is_deeply(
            maybe_decode_json( $mech->content() ),
            {
                data => [{
                    type    => "publication",
                    id      => "1",
                    links   => {
                        self => "${uri_base}/api/v1/publication/1/versions/1"
                    },
                    attributes => {
                        _id         => "1",
                        _version    => "1"
                    }
                }]
            },
            "GET /api/v1/publication/:id/versions -> response body ok"
        );

        # GET /api/v1/publication/:id/versions/:version
        $mech->get( "/api/v1/publication/1/versions/1", %headers );

        is( $mech->status, 200, "GET /api/v1/publication/:id/versions/:version -> status 200" );

        is_deeply(
            maybe_decode_json( $mech->content() ),
            {
                data => {
                    type    => "publication",
                    id      => "1",
                    links   => {
                        self => "${uri_base}/api/v1/publication/1/versions/1"
                    },
                    attributes => $test_record
                }
            },
            "GET /api/v1/publication/:id/versions/:version -> response body ok"
        );

        # POST /api/v1/publication with forbidden attribute "file"
        $mech->post(
            "/api/v1/publication",
            %headers,
            Content => encode_json({
                _id     => 1,
                type    => "book",
                status  => "new",
                title   => "my little pony: part 2",
                file    => []
            })
        );

        is( $mech->status(), 403, "POST /api/v1/publication with forbidden attribute file -> status 403" );

        is_deeply(
            maybe_decode_json( $mech->content() ),
            {
                errors => [{
                    status => "403",
                    title  => "Forbidden to update attribute file in this route",
                    source => { pointer => "/file" }
                }]
            },
            "POST /api/v1/publication with forbidden attribute file -> response body ok"
        );


    }

};

done_testing;
