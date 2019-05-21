package LibreCat::Controller::Api;

use Catmandu::Sane;
use Catmandu -all;
use LibreCat -self;
use Path::Tiny;
use Mojo::Base 'Mojolicious::Controller';
use namespace::clean;

sub openapi_json {
    my $c = $_[0];
    $c->render(json => $c->openapi_doc);
}

sub openapi_yml {
    my $c = $_[0];
    $c->render(text => export_to_string($c->openapi_doc, 'YAML'), format => 'yml');
}

sub openapi_doc {
    my $yaml =
    Catmandu->importer('YAML',
        file =>
            path(librecat->root_path)->child('views/api/openapi_before.yml')->stringify,
        )->first;

    $yaml->{paths} = +{};
    foreach my $m (@{librecat->models}) {
        push @{$yaml->{tags}},
            {name => $m, description => "Operations on $m records."};

        my $tmp_exp;
        my $path_exporter = Catmandu->exporter(
            'Template',
            file => \$tmp_exp,
            template => path(librecat->root_path)->child('views/api/openapi_path.yml.tt')->stringify,
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
