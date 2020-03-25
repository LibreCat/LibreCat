package LibreCat::App::Api::json_api_v1;

use Catmandu::Sane;
use Catmandu::Error;
use LibreCat::Error::RecordNotFound;
use Catmandu::Util qw(:is :array);
use Hash::Merge::Simple qw(merge);
use LibreCat -self;
use Dancer qw(:script);
use LibreCat::App::Helper;
use Try::Tiny;
use LibreCat::Validator::JSONSchema;
use URI::Escape qw(uri_escape_utf8 uri_escape);

my $JSON_API_MIMETYPE = "application/vnd.api+json";
my $JSON_API_VERSION   = "1.0";

# /api/v1
hook before => sub {

    my $request     = request();
    my $env         = $request->env();
    my $path_info   = $request->path_info();

    if( index( $path_info,"/api/v1" ) == 0 ){

        #disable storing of sessions for /api/v1
        #note that the cookie is still sent
        $env->{"psgix.session.options"} //= {};
        $env->{"psgix.session.options"}->{no_store} = 1;

        if(
            $path_info ne "/api/v1/_access_denied" &&
            $path_info ne "/api/v1/_authorization_required"
        ){

            #ip access denied: 403
            unless(
                h->within_ip_range(
                    $request->address(),
                    ip_ranges()
                )
            ){

                #the only to stop the current request is to change the path to another route
                return $request->path_info( "/api/v1/_access_denied" );

            }

            #jwt authentication -> Authorization:Bearer my.long.token
            my $auth = $request->header( "Authorization" );
            unless( is_string( $auth ) ){

                return $request->path_info( "/api/v1/_authorization_required" );

            }

            my($bearer,$token) = split( /\s+/o, $auth );
            my $jwt_payload;

            unless(
                is_string( $bearer ) &&
                is_string( $token ) &&
                lc( $bearer ) eq "bearer" &&
                ($jwt_payload = librecat->token->decode( $token ))
            ){

                return $request->path_info( "/api/v1/_access_denied" );

            }

            var jwt_payload => $jwt_payload;

            #Content-Negotiation
            #cf. https://jsonapi.org/format/#content-negotiation-servers

            my $accept = $request->header( "Accept" );
            my $acceptable = [ "*/*", "application/json", $JSON_API_MIMETYPE ];
            unless( array_includes($acceptable,$accept) ){

                return $request->path_info( "/api/v1/_not_acceptable" );

            }

            my $req_method = $request->method();
            my $content_type = $request->header( "Content-Type" );

            if( $req_method eq "PUT" || $req_method eq "PATCH" || $req_method eq "POST" ){

                if ( $content_type ne $JSON_API_MIMETYPE ){

                    return $request->path_info( "/api/v1/_unsupported_media_type" );

                }

            }

        }

    }

};

prefix "/api/v1" => sub {

    #routes for internal use.
    any "/_access_denied" => sub {

        json_errors(
            403,
            [ { status => "403", title => "access denied" } ]
        );

    };

    any "/_authorization_required" => sub {

        json_errors(
            401,
            [ { status => "401", title => "authorization required" } ]
        );

    };

    any "/_not_acceptable" => sub {

        json_errors(
            406,
            [ { status => "406", title => "not acceptable" } ]
        );

    };

    any "/_unsupported_media_type" => sub {

        json_errors(
            415,
            [ { status => "415", title => "Unsupported Media Type" } ]
        );

    };

    # GET /api/v1/:model/:id
    get "/:model/:id" => sub {

        show_model_record( params("route") );

    };

    # DELETE /api/v1/:model/:id
    del "/:model/:id" => sub {

        delete_model_record( params("route") );

    };

    # PUT /api/v1/:model/:id
    put "/:model/:id" => sub {

        update_model_record( params("route") );

    };

    # PATCH /api/v1/:model/:id
    patch "/:model/:id" => sub {

        patch_model_record( params("route") );

    };

    # POST /api/v1/:model
    post "/:model" => sub{

        create_model_record( params("route") );

    };

    # GET /api/v1/:model/versions
    get "/:model/:id/versions" => sub {

        show_model_record_history( params("route") );

    };

    # GET /api/v1/:model/versions/:version
    get "/:model/:id/versions/:version" => sub {

        show_model_version( params("route") );

    };


    # catch all route for /api/v1
    any qr(.*) => sub {

        not_found( title => "route not found" );

    };

};

sub show_model_record {

    my(%args) = @_;

    my $model_name = delete $args{model};
    my $id    = delete $args{id};

    my $model = librecat->model( $model_name ) // return not_found( title => "model $model_name not found" );
    my $rec   = $model->get( $id ) // return not_found( title => "record $id not found in model $model_name" );
    my $req   = request();
    my $self_uri = $req->uri_for( $req->path_info() )->as_string();
    my $data = {
        type       => $model_name,
        id         => $id,
        attributes => $rec,
        links      => { self => $self_uri },
    };

    #jwt validation
    forward( "/api/v1/_access_denied" )
        unless jwt_valid(
            payload => var("jwt_payload"),
            model   => $model,
            action  => "show",
            id      => $id
        );

    if( $model->does("LibreCat::Model::Plugin::Versioning") ){

        $data->{relationships} = {
            versions => {
                links => {
                    related => "${self_uri}/versions"
                }
            }
        };

    }

    json_response( 200,{ data => $data } );

}

sub create_model_record {

    my(%args) = @_;

    my $model_name = delete $args{model};
    my $model = librecat->model( $model_name ) // return not_found( title => "model $model_name not found" );
    my $parse_error;
    my $req   = request();

    #jwt validation
    forward( "/api/v1/_access_denied" )
        unless jwt_valid(
            payload => var("jwt_payload"),
            model   => $model,
            action  => "create"
        );

    #validate request body against json api v1 spec
    my($body,@body_errors) = validate_request_body();

    return json_errors(
        400,
        \@body_errors
    ) unless defined( $body );

    #model name and body.type must be consistent
    if( $model_name ne $body->{data}->{type} ){

        return json_errors(
            400,
            [{
                status => "400",
                title  => "model in route path and type in /data/type must match"
            }]
        );

    }

    my $id      = $body->{data}->{id};
    my $attrs   = $body->{data}->{attributes};

    #only allow identifier in /data/id
    if( exists( $attrs->{_id} ) ){

        return json_errors(
            400,
            [{
                status => "400",
                title  => "identifier should only be supplied in /data/id",
                source => { pointer => "/data/attributes/_id" }
            }]
        );

    }

    # save data
    # three steps all in one transaction:
    #   1) if user has supplied an id, then the record should not exist
    #   2) validate the record
    #   3) save the record
    # if one of the steps fail, the save action should be cancelled
    my $http_content;

    try{

        $model->bag()->store()->transaction(sub{

            # step 1)
            if( is_string( $id ) ){

                Catmandu::Error->throw( "record $id already present in model $model_name" )
                    if $model->get( $id );

                $attrs->{_id} = $id;

            }

            # step 2) and 3)
            librecat->hook( "json-api-v1-${model_name}-create" )->fix_around(
                $attrs,
                sub {
                    $model->add(
                        $attrs,
                        on_validation_error => sub {
                            my ($x, $errors) = @_;
                            $http_content = json_errors(
                                400,
                                [
                                    map {
                                        my $e = librecat_error_to_json_error( $_ );
                                        $e->{source}->{pointer} = "/data/attributes".$e->{source}->{pointer};
                                        $e;
                                    }
                                    @$errors
                                ]
                            );
                        },
                        on_success => sub {
                            my $new_record = shift;
                            my $self_uri = $req->uri_for( $req->path_info )->as_string()."/".uri_escape($new_record->{_id});

                            my $d = {
                                type       => $model_name,
                                id         => $new_record->{_id},
                                attributes => $new_record,
                                links      => { self => $self_uri },
                            };

                            if( $model->does("LibreCat::Model::Plugin::Versioning") ){

                                $d->{relationships} = {
                                    versions => {
                                        links => {
                                            related => "${self_uri}/versions"
                                        }
                                    }
                                };

                            }

                            # send created status 201
                            $http_content = json_response( 201,{ data => $d } );
                        }
                    );
                }
            );

        });

    } catch {

        #P.S. version conflict does not happen during creation (?)
        if( is_instance( $_, "Catmandu::Error" ) ){

            $http_content = json_response( 400, {
                errors => [{
                    status => "400",
                    title  => $_->message()
                }]
            });

        }
        else {

            $http_content = json_response( 500, {
                errors => [{
                    status => "500",
                    #hopefully this message is overloaded so it is nicely converted into a string
                    title  => "$_"
                }]
            });

        }

    };

    $http_content;

}

sub update_model_record {

    my(%args) = @_;

    my $model_name = delete $args{model};
    my $route_id   = delete $args{id};

    my $model = librecat->model( $model_name ) // return not_found( title => "model $model_name not found" );
    my $parse_error;
    my $req   = request();

    #jwt validation
    forward( "/api/v1/_access_denied" )
        unless jwt_valid(
            payload => var("jwt_payload"),
            model   => $model,
            action  => "update",
            id      => $route_id
        );

    #validate request according to JSON API
    my($body,@body_errors) = validate_request_body();

    return json_errors(
        400,
        \@body_errors
    ) unless defined( $body );

    #model name and /data/type must be consistent
    if( $model_name ne $body->{data}->{type} ){

        return json_errors(
            400,
            [{
                status => "400",
                title  => "model in route path and type in /data/type must match"
            }]
        );

    }

    # id in route and /data/id must match
    unless(
        is_string($body->{data}->{id}) &&
        $route_id eq $body->{data}->{id}
    ){

        return json_errors(
            400,
            [{
                status => "400",
                title  => "id in route path and id in /data/id must match"
            }]
        );

    }

    my $id          = $body->{data}->{id};
    my $attrs       = $body->{data}->{attributes};
    $attrs->{_id}   = $id;

    my $http_content;

    try{

        $model->bag()->store()->transaction(sub{

            # old record must exist
            my $old_record = $model->get( $id );

            LibreCat::Error::RecordNotFound->throw(
                model => $model,
                id    => $id
            ) unless $old_record;

            librecat->hook( "json-api-v1-${model_name}-update" )->fix_around(
                $attrs,
                sub {
                    $model->add(
                        $attrs,
                        on_validation_error => sub {
                            my ($x, $errors) = @_;
                            $http_content = json_errors(
                                400,
                                [
                                    map {
                                        my $e = librecat_error_to_json_error( $_ );
                                        $e->{source}->{pointer} = "/data/attributes".$e->{source}->{pointer};
                                        $e;
                                    }
                                    @$errors
                                ]
                            );
                        },
                        on_success => sub {
                            my $new_record = shift;
                            my $self_uri = $req->uri_for( $req->path_info() )->as_string();

                            my $d = {
                                type       => $model_name,
                                id         => $new_record->{_id},
                                attributes => $new_record,
                                links      => { self => $self_uri }
                            };

                            if( $model->does("LibreCat::Model::Plugin::Versioning") ){

                                $d->{relationships} = {
                                    versions => {
                                        links => {
                                            related => "${self_uri}/versions"
                                        }
                                    }
                                };

                            }

                            $http_content = json_response( 200,{ data => $d } );
                        }
                    );
                }
            );

        });

    } catch {

        if( is_instance( $_,"LibreCat::Error::VersionConflict" ) ){

            $http_content = json_response( 400, {
                errors => [{
                    status => "400",
                    title  => h->localize("error.version_conflict")
                }]
            });

        }
        elsif( is_instance( $_,"LibreCat::Error::RecordNotFound" ) ){

            $http_content = json_response( 404, {
                errors => [{
                    status => "404",
                    title  => $_->message()
                }]
            });

        }
        elsif( is_instance( $_, "Catmandu::Error" ) ){

            $http_content = json_response( 400, {
                errors => [{
                    status => "400",
                    title  => $_->message()
                }]
            });

        }
        else {

            $http_content = json_response( 500, {
                errors => [{
                    status => "500",
                    #hopefully this message is overloaded so it is nicely converted into a string
                    title  => "$_"
                }]
            });

        }

    };

    $http_content;

}

sub patch_model_record {

    my(%args) = @_;

    my $model_name = delete $args{model};
    my $route_id   = delete $args{id};

    my $model = librecat->model( $model_name ) // return not_found( title => "model $model_name not found" );
    my $parse_error;
    my $req   = request();

    #jwt validation
    forward( "/api/v1/_access_denied" )
        unless jwt_valid(
            payload => var("jwt_payload"),
            model   => $model,
            action  => "patch",
            id      => $route_id
        );

    #validate request according to JSON API
    my($body,@body_errors) = validate_request_body();

    return json_errors(
        400,
        \@body_errors
    ) unless defined( $body );

    #check consistencies
    if( $model_name ne $body->{data}->{type} ){

        return json_errors(
            400,
            [{
                status => "400",
                title  => "model in route path and type in /data/type must match"
            }]
        );

    }

    unless(
        is_string($body->{data}->{id}) &&
        $route_id eq $body->{data}->{id}
    ){

        return json_errors(
            400,
            [{
                status => "400",
                title  => "id in route path and id in /data/id must match"
            }]
        );

    }

    my $id          = $body->{data}->{id};
    my $attrs       = $body->{data}->{attributes};
    $attrs->{_id}   = $id;

    my $http_content;

    try{

        $model->bag()->store()->transaction(sub{

            # old record must exist
            my $old_record = $model->get( $id );

            LibreCat::Error::RecordNotFound->throw(
                model => $model,
                id    => $id
            ) unless $old_record;

            # merge old and new
            $attrs = merge( $old_record, $attrs );

            librecat->hook( "json-api-v1-${model_name}-patch" )->fix_around(
                $attrs,
                sub {
                    $model->add(
                        $attrs,
                        on_validation_error => sub {
                            my ($x, $errors) = @_;
                            $http_content = json_errors(
                                400,
                                [
                                    map {
                                        my $e = librecat_error_to_json_error( $_ );
                                        $e->{source}->{pointer} = "/data/attributes".$e->{source}->{pointer};
                                        $e;
                                    }
                                    @$errors
                                ]
                            );
                        },
                        on_success => sub {
                            my $new_record = shift;
                            my $self_uri = $req->uri_for( $req->path_info() )->as_string();

                            my $d = {
                                type       => $model_name,
                                id         => $new_record->{_id},
                                attributes => $new_record,
                                links      => { self => $self_uri },
                            };

                            if( $model->does("LibreCat::Model::Plugin::Versioning") ){

                                $d->{relationships} = {
                                    versions => {
                                        links => {
                                            related => "${self_uri}/versions"
                                        }
                                    }
                                };

                            }

                            $http_content = json_response( 200,{ data => $d } );
                        }
                    );
                }
            );

        });

    } catch {

        if( is_instance( $_,"LibreCat::Error::VersionConflict" ) ){

            $http_content = json_response( 400, {
                errors => [{
                    status => "400",
                    title  => h->localize("error.version_conflict")
                }]
            });

        }
        elsif( is_instance( $_,"LibreCat::Error::RecordNotFound" ) ){

            $http_content = json_response( 404, {
                errors => [{
                    status => "404",
                    title  => $_->message()
                }]
            });

        }
        elsif( is_instance( $_, "Catmandu::Error" ) ){

            $http_content = json_response( 400, {
                errors => [{
                    status => "400",
                    title  => $_->message()
                }]
            });

        }
        else {

            $http_content = json_response( 500, {
                errors => [{
                    status => "500",
                    #hopefully this message is overloaded so it is nicely converted into a string
                    title  => "$_"
                }]
            });

        }

    };

    $http_content;

}

#TODO: what should this method: $model->delete or actually $model->purge
#      in the latter case /data/attributes can simply contain "status:deleted"
#      while in the first case the data should contain the fully updated record
sub delete_model_record {

    my(%args) = @_;

    my $model_name = delete $args{model};
    my $id    = delete $args{id};

    my $model = librecat->model( $model_name ) // return not_found( title => "model $model_name not found" );
    my $rec   = $model->get( $id ) // return not_found( title => "record $id not found in model $model_name" );
    my $req   = request();

    #jwt validation
    forward( "/api/v1/_access_denied" )
        unless jwt_valid(
            payload => var("jwt_payload"),
            model   => $model,
            action  => "delete",
            id      => $id
        );

    librecat->hook("json-api-v1-${model_name}-delete")->fix_around(
        $rec,
        sub {
            $model->delete($id);
        }
    );

    my $data = {
        type       => $model_name,
        id         => $id,
        attributes => { status => "deleted" },
        links      => { self => $req->uri_for( $req->path_info() )->as_string() },
    };

    json_response( 200,{ data => $data } );

}

sub show_model_record_history {

    my(%args) = @_;

    my $model_name = delete $args{model};
    my $id    = delete $args{id};

    my $model = librecat->model( $model_name ) // return not_found( title => "model $model_name not found" );

    # history not supported for this model
    unless( $model->does("LibreCat::Model::Plugin::Versioning") ){

        return json_errors(
            400,
            [{ status => "400", title => "no versioning is enabled for model $model_name" }]
        );

    }

    #jwt validation
    forward( "/api/v1/_access_denied" )
        unless jwt_valid(
            payload => var("jwt_payload"),
            model   => $model,
            action  => "show",
            id      => $id
        );

    my $versions = $model->get_history( $id ) // return not_found( title => "record $id not found in model $model_name" );
    my $req = request();
    my $parent_uri_base = $req->uri_for( $req->path_info() )->as_string();
    my $data = [
        map {

            +{
                type => $model_name,
                id => $_->{_id},
                attributes => {
                    _id => $_->{_id},
                    _version => $_->{_version}
                },
                links => {
                    self => "${parent_uri_base}/".$_->{_version}
                }
            };

        } @$versions
    ];

    json_response( 200, { data => $data } );

}

sub show_model_version {

    my(%args) = @_;

    my $model_name   = delete $args{model};
    my $id      = delete $args{id};
    my $version = delete $args{version};

    my $model   = librecat->model( $model_name ) // return not_found( title => "model $model_name not found" );

    # history not supported for this model
    unless( $model->does("LibreCat::Model::Plugin::Versioning") ){

        return json_errors(
            400,
            [{ status => "400", title => "no versioning is enabled for model $model_name" }]
        );

    }

    #jwt validation
    forward( "/api/v1/_access_denied" )
        unless jwt_valid(
            payload => var("jwt_payload"),
            model   => $model,
            action  => "show",
            id      => $id
        );

    my $rec     = $model->get_version( $id, $version ) // return not_found( title => "version $version not found for record $id of model $model_name" );
    my $req     = request();
    my $data    = {
        type       => $model_name,
        id         => $id,
        attributes => $rec,
        links      => { self => $req->uri_for( $req->path_info() )->as_string() },
    };

    json_response( 200, { data => $data } );

}

sub not_found {

    my(%args) = @_;

    json_errors(
        404,
        [ { status => "404", title => $args{title} } ]
    );

}

# cf. https://jsonapi.org/format/#error-objects
sub json_errors {

    my($status,$errors) = @_;

    json_response(
        $status,
        { errors => $errors }
    );

}

sub json_response {

    my($status,$response) = @_;

    $response->{jsonapi} = { version => $JSON_API_VERSION };

    status $status;
    content_type $JSON_API_MIMETYPE;
    to_json( $response );

}

sub ip_ranges {

    state $i = do {
        my $ip_range = librecat->config->{json_api_v1}->{ip_range};
        is_array_ref( $ip_range ) ? $ip_range : [];
    };

}

sub librecat_error_to_json_error {

    my $err = $_[0];

    +{
        code => $err->code(),
        status => "400",
        title => $err->localize(),
        source => {
            pointer => "/" . join( "/",split( /\./o, $err->property() ) )
        }
    }

}

sub validate_request_body {

    state $v = LibreCat::Validator::JSONSchema->new(
        namespace => "validator.json_api_v1.errors",
        schema => {
            '$schema'   => "http://json-schema.org/draft-04/schema#",
            title       => "librecat audit record",
            type        => "object",
            properties  => {
                data    => {
                    type    => "object",
                    properties => {
                        id          => {
                            type        => "string",
                            minLength   => 1
                        },
                        type        => {
                            type        => "string",
                            minLength   => 1
                        },
                        attributes  => {
                            type => "object"
                        }
                    },
                    required => ["type","attributes"],
                    additionalProperties => 0
                }
            },
            required => ["data"],
            additionalProperties => 0
        }
    );


    my $parse_error;
    my $body;

    #parse json body
    try {

        $body = from_json( request()->body() );

    }catch {

        $parse_error = $_;

    };

    return undef, [ { status => "400", title => "malformed JSON string" } ]
        if defined( $parse_error );

    #validate request body agains json api v1 spec
    return $body if $v->is_valid( $body );

    my @errors = map { librecat_error_to_json_error( $_ ); } @{ $v->last_errors() };

    undef, @errors;
}

sub jwt_valid {

    my(%args) = @_;

    my $payload     = delete $args{payload};
    my $model       = delete $args{model};
    my $id          = delete $args{id};
    my $action      = delete $args{action};

    if( is_string( $payload->{model} ) && lc($payload->{model}) ne lc($model->name) ){

        return 0;

    }
    elsif( is_array_ref( $payload->{action} ) && !array_includes( $payload->{action}, $action ) ){

        return 0;

    }elsif(
        is_string( $payload->{cql} ) &&
        is_string( $id )
    ){

        my $query;
        my $parse_error;
        try {
            $query = $model->search_bag()->translate_cql_query( $payload->{cql} );
        }catch{
            $parse_error = $_;
            h->log->error("unable to convert cql from jwt into ES query: $parse_error");
        };
        return 0 if defined( $parse_error );

        my $hits  = $model->search_bag()->search(
            query => {
                bool => {
                    must => $query,
                    filter => {
                        term => {
                            _id => $id
                        }
                    }
                }
            },
            limit => 0
        );
        return $hits->total() > 0;

    }

    1;
}

=head1 NAME

LibreCat::App::Api::json_api_v1 - json api v1 implementation for librecat models

=head1 JSON API v1.0 for LibreCat models

=head2 Authentication

The JSON API uses two layers of authentication

=head3 IP based authentication

Configure the ip ranges in the Catmandu config at key `json_api_v1.ip_range`:

    json_api_v1:
      ip_range: [ "157.193.0.0/16" ]

One can always set the ip_range to 0.0.0.0/0 and handle this in the proxy server

or - even better - in the firewall.

=head3 JWT based authentication

Configure JWT secret in the Catmandu config at key 'json_api_v1.token_secret`:

    json_api_v1:
      token_secret: "areyoureallytryingtoreadthis"

A JWT token can be generated by use of the LibreCat CLI:

    $ ./bin/librecat token encode

A client adds this token as bearer token in the header `Authorization`

    $ curl -H "Authorization:Bearer my.jwt.token" "http://localhost:5001/api/v1/publicaton/1"

Possible errors that relate to authentication:

* 401: Authorization required

    {
       "errors" : [
          {
             "title" : "authorization required",
             "status" : "401"
          }
       ]
    }

* 403: Access denied

    {
       "errors" : [
          {
             "title" : "access denied",
             "status" : "403"
          }
       ]
    }

=head2 ROUTES

=head3 POST /api/v1/:model

Create a new record of type :model (e.g. "publication")

A JSON request body must be made that looks like this:

    {
        "data" : {
            "type": $model,
            "attributes" : $record
        }
    }

See also https://jsonapi.org/format/#crud-creating

JSON path /data/id can also contain a user supplied identifier, but it cannot yet exist.

The new identifier may only exist in /data/id.

JSON path /data/type must equal the model name in the route.

When successfull, http status 201 is returned and the record

is returned as if you would have called `GET /api/v1/:model/:id` (see below):

    $ token="my.jwt.token"
    $ curl -XPOST "http://localhost:5001/api/v1/publication" -H "Authorization:Bearer $token" -d '{ "title":"test", "status": "new", "type" : "book" }'

    {
       "data" : {
          "links" : {
             "self" : "http://localhost:5001/api/v1/publication/9117"
          },
          "type" : "publication",
          "id" : "9117",
          "attributes" : {
             "type" : "book",
             "title" : "test",
             "date_updated" : "2020-03-12T10:12:46Z",
             "_id" : "9117",
             "date_created" : "2020-03-12T10:12:46Z",
             "status" : "new"
          },
          "relationships" : {
             "versions" : {
                "links" : {
                   "related" : "http://localhost:5001/api/v1/publication/9117/versions"
                }
             }
          }
       }
    }

Possible errors:

* 404: model :model not found

    {
       "errors" : [
          {
             "title" : "model rubbish not found",
             "status" : "404"
          }
       ]
    }

* 400: model in route path and type in /data/type must match

    {
        "errors" : [
            {
                "status" : "400",
                "title" : "model in route path and type in /data/type must match"
            }
        ]

    }

* 400: identifier should only be supplied in /data/id

    {
        "errors" : [
            {
                "status" : "400",
                "title" : "identifier should only be supplied in /data/id",
                "source" : { "pointer" : "/data/attributes/_id" }
            }
        ]
    }

* 400: record :id already present in model :model

    {
       "errors" : [
          {
             "title" : "record 1 already present in model publication",
             "status" : "404"
          }
       ]
    }

* 400: malformed json string

    {
       "errors" : [
          {
             "status" : "400",
             "title" : "malformed JSON string"
          }
       ]
    }

* 400: validation error

    {
       "errors" : [
          {
             "source" : {
                "pointer" : "/type"
             },
             "title" : "type is required",
             "code" : "object.required",
             "status" : "400"
          }
       ]
    }

=head3 GET /api/v1/:model/:id

Retrieve record :id of model :model.

Status code is either 200 or 404:

    {
       "data" : {
          "links" : {
             "self" : "http://localhost:5001/api/v1/publication/9117"
          },
          "type" : "publication",
          "id" : "9117",
          "attributes" : {
             "type" : "book",
             "title" : "test",
             "date_updated" : "2020-03-12T10:12:46Z",
             "_id" : "9117",
             "date_created" : "2020-03-12T10:12:46Z",
             "status" : "new"
          },
          "relationships" : {
             "versions" : {
                "links" : {
                   "related" : "http://localhost:5001/api/v1/publication/9117/versions"
                }
             }
          }
       }
    }

When applicable the response includes a link to the versions in the attribute `/data/relationships/versions`

=head3 DELETE /api/v1/:model/:id

Delete record :id of model :id.

Status code is either 200 or 404:

    {
       "data" : {
          "attributes" : {
             "status" : "deleted"
          },
          "id" : "9117",
          "type" : "publication",
          "links" : {
             "self" : "http://localhost:5001/api/v1/publication/9117"
          }
       }
    }

Note that for the model "publication", a "delete" does not actually delete the record:

the "status" is simply set to "deleted", so you can still do actions on this record in the json api.

For other models the delete is equal to "purge", so the record is gone.

=head3 PUT /api/v1/:model/:id

Fully overwrite record :id of model :model.

Same response as the route "POST /api/v1/:model",

but in this case the record with identifier :id should preexist.

=head3 PATCH /api/v1/:model/:id

Only update certain fields of record :id in model :model.

These new fields are (deeply) merged into the old record.

Note that a deep merge only works for hashes. An array is always

completely overwritten.

Same response and errors as for the route "PUT /api/v1/:model"

=head3 GET /api/v1/:model/:id/versions

Retrieve older versions of record :id of model :model.

Only a short description and a link to the full record is supplied.

Status code and errors are the same as for `GET /api/v1/:model/:id`.

Response:

    {
       "data" : [
          {
             "links" : {
                "self" : "http://localhost:5001/api/v1/publication/9117/versions/3"
             },
             "type" : "publication",
             "id" : "9117",
             "attributes" : {
                "_version" : 3,
                "_id" : "9117"
             }
          },
          {
             "id" : "9117",
             "attributes" : {
                "_version" : 2,
                "_id" : "9117"
             },
             "links" : {
                "self" : "http://localhost:5001/api/v1/publication/9117/versions/2"
             },
             "type" : "publication"
          },
          {
             "type" : "publication",
             "links" : {
                "self" : "http://localhost:5001/api/v1/publication/9117/versions/1"
             },
             "attributes" : {
                "_id" : "9117",
                "_version" : 1
             },
             "id" : "9117"
          }
       ]
    }

Additional errors:

* 400: versioning not configured for model :model

    {
       "errors" : [
          {
             "title" : "no versioning is enabled for model department",
             "status" : "400"
          }
       ]
    }


=head3 GET /api/v1/:model/:id/versions/:version

Same http status, response and errors as for route `GET /api/v1/:model/:id`.

Additional errors:

* 400: versioning not configured for model :model

    {
       "errors" : [
          {
             "title" : "no versioning is enabled for model department",
             "status" : "400"
          }
       ]
    }

=cut

1;
