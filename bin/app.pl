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
use Catmandu::Util qw(require_package :is);
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

# setup sessions
my $config = config;
my $session_store_package = is_string($config->{session_store}->{package}) ?
    $config->{session_store}->{package} : "Plack::Session::Store";
my $session_store_options = is_hash_ref($config->{session_store}->{options}) ?
    $config->{session_store}->{options} : {};
my $session_state_package = is_string($config->{session_state}->{package}) ?
    $config->{session_state}->{package} : "Plack::Session::State::Cookie";
my $session_state_options = is_hash_ref($config->{session_state}->{options}) ?
    $config->{session_state}->{options} : {};

builder {
    enable 'ReverseProxy';
    enable 'Deflater';
    enable 'Session',
        store => require_package( $session_store_package )->new( %$session_store_options ),
        state => require_package( $session_state_package )->new( %$session_state_options );
     enable 'CSRFBlock',
         parameter_name => "csrf_token",
         meta_tag => "csrf_token",
         header_name => "X-CSRF-Token",
         token_length => 40,
         session_key => "csrf_token";
    $app;
};
