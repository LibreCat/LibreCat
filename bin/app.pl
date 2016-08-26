#!/usr/bin/env perl

my $layers;

BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    $layers = LibreCat::Layers->new->load;
};

use Catmandu::Sane;
use Plack::Builder;
use Plack::App::File;
use Plack::App::Cascade;
use Dancer;
use App;

# setup template paths
config->{engines}{template_toolkit}{INCLUDE_PATH} = $layers->template_paths;
config->{engines}{template_toolkit}{DEBUG} //= 'provider' if config->{log} eq 'core' || config->{log} eq 'debug';

# setup static file serving
my $app = Plack::App::Cascade->new;
$app->add(map {Plack::App::File->new(root => $_)->to_app} @{$layers->public_paths});
# dancer app
$app->add(sub {
    Dancer->dance(Dancer::Request->new(env => $_[0]));
});

builder {
    enable "ReverseProxy";
    enable "Deflater";
#    enable "Negotiate",
#        formats => {
#            html => { type => 'text/html', language => 'en' },
#            yaml => { type => 'text/x-yaml' },
#            json => { type => 'application/json' },
#            bibtex => { type => 'text/x-bibtex' },
#            ris => { type => 'application/x-research-info-systems' },
#            dc => { type => 'application/oaidc+xml' },
#            mods => { type => 'application/mods+xml' },
#            dc_json => { type => 'application/oaidc+json' },
#            csl_json => { type => 'application/vnd.citationstyles.csl+json' },
#            _ => {
#                #size => 0,
#                charset => 'utf-8',
#                }  # default values for all formats
#        },
#        parameter => 'fmt', # e.g. http://example.org/foo?format=xml
#        extension => 'strip';  # e.g. http://example.org/foo.xml
    $app;
};
