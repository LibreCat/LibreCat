#!/usr/bin/env perl

use Dancer;
use FindBin qw($Bin);
use App;

use Plack::Builder;

my $app = sub {
    my $env = shift;
    my $request = Dancer::Request->new( env => $env );
    Dancer->dance($request);
};

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
