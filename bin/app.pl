#!/usr/bin/env perl

BEGIN {
    use Catmandu::Sane;
    use Catmandu;
    use Log::Log4perl;
    use Log::Any::Adapter;
    use Path::Tiny;

    # load catmandu config
    Catmandu->load(path(__FILE__)->parent->parent);

    # setup logging
    Log::Log4perl->init(path(Catmandu->root)->child('log4perl.conf')->canonpath);
    Log::Any::Adapter->set('Log4perl');
}

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(require_package :is);
use LibreCat::Layers;
use Plack::Builder;
use Plack::App::File;
use Plack::App::Cascade;
use Dancer;
use App;

my $layers = LibreCat::Layers->new;

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
    # enable 'CSRFBlock',
    #     parameter_name => "csrf_token",
    #     meta_tag => "csrf_token",
    #     header_name => "X-CSRF-Token",
    #     token_length => 16,
    #     session_key => "csrf_token",
    #     blocked => sub {
    #         [301,["Location" => "/access_denied" ],["action forbidden"]];
    #     };
    $app;
};
