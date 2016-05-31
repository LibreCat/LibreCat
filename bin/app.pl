#!/usr/bin/env perl

use Dancer qw(:syntax);
#use FindBin qw($Bin);
use LibreCat::Layers;
use App;
use Log::Log4perl;
use Log::Any::Adapter;
use Plack::Builder;

my $layers = LibreCat::Layers->new->load;

setting apphandler => 'PSGI';

Dancer::Config->load;

config->{engines}{template_toolkit}{INCLUDE_PATH} = $layers->{template_paths};

my $app = sub {
    my $env = shift;
    my $req = Dancer::Request->new(env => $env);
    Dancer->dance($req);
};

Log::Log4perl::init('log4perl.conf');
Log::Any::Adapter->set('Log4perl');

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
