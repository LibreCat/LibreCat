#!/usr/bin/env perl

BEGIN {
    use Catmandu::Sane;
    use Catmandu;
    use Path::Tiny;
    Catmandu->load(path(__FILE__)->parent->parent);
}

use Catmandu::Sane;
use Dancer;
use LibreCat::Layers;
use App;
use Plack::Builder;
use Plack::App::File;
use Plack::App::Cascade;
use Log::Log4perl;
use Log::Any::Adapter;
use Path::Tiny;

my $layers = LibreCat::Layers->new;

# setup logging
Log::Log4perl->init(path(Catmandu->root)->child('log4perl.conf')->canonpath);
Log::Any::Adapter->set('Log4perl');

# configure dancer
my $dancer_config = Catmandu->config->{dancer};
# setup template paths
$dancer_config->{engines}{template_toolkit}{INCLUDE_PATH} = $layers->template_paths;
set $_ => $dancer_config->{$_} for keys %$dancer_config;
Dancer::Config->load;

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
