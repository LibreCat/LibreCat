#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat qw(:load :self);
use Mojo::Server::PSGI;
use LibreCat::Application;

my $mojo_app    = LibreCat::Application->new();
my $app         = Mojo::Server::PSGI->new();
my $path        = librecat->config->{api}{v1}{path};

#Set base path when served behind a proxy server
# e.g. '/api'
$mojo_app->hook(before_dispatch => sub {

    $_[0]->req->url->base->path( $path );

}) if is_string( $path );

$app = $app->app( $mojo_app );

#Set host and scheme based on headers X-Forwarded-* when served behind a proxy server
$app = $app->reverse_proxy(1)
    if is_string( $path );

$app->to_psgi_app();
