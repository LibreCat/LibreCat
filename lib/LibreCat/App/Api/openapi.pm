package LibreCat::App::Api::openapi;

use Catmandu::Sane;
use Catmandu;
use LibreCat -self;
use Path::Tiny qw();
use Dancer qw(:script);

hook before => sub {

    my $request     = request();
    my $env         = $request->env();
    my $path_info   = $request->path_info();

    #disable storing of sessions for /openapi.json and /openapi.yml
    #note that the cookie is still sent
    if( $path_info eq '/openapi.json' || $path_info eq '/openapi.yml' ){

        $env->{'psgix.session.options'} //= {};
        $env->{'psgix.session.options'}->{no_store} = 1;

    }

};

get '/openapi.json' => \&openapi_json;

get '/openapi.yml'  => \&openapi_yml;

sub openapi_json {
    content_type 'application/json';
    to_json( openapi_doc() );
}

sub openapi_yml {
    content_type 'text/x-yaml';
    to_yaml( openapi_doc() );
}

sub openapi_doc {
    my $yaml =
    Catmandu->importer('YAML',
        file =>
            Path::Tiny::path(librecat->root_path)->child('views/api/openapi_before.yml')->stringify,
        )->first;

    $yaml->{paths} = +{};
    foreach my $m (@{librecat->models}) {
        push @{$yaml->{tags}},
            {name => $m, description => 'Operations on $m records.'};

        my $tmp_exp;
        my $path_exporter = Catmandu->exporter(
            'Template',
            file => \$tmp_exp,
            template => Path::Tiny::path(librecat->root_path)->child('views/api/openapi_path.yml.tt')->stringify,
        );
        $path_exporter->add({item => $m});
        $path_exporter->commit;

        $yaml->{paths} = {
            %{$yaml->{paths}},
            %{Catmandu->importer('YAML', file => \$tmp_exp)->first}
        };
    }

    $yaml->{components}->{schemas} = librecat->config->{schemas};

    foreach my $k (keys %{$yaml->{components}->{schemas}}) {
        delete $yaml->{components}->{schemas}->{$k}->{'$schema'};
    }

    $yaml;
}

1;
