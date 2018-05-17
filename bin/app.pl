#!/usr/bin/env perl

# TODO very dirty, this prevents Dancer from prepending lib/ in @INC
use Dancer::ModuleLoader;
{
    no warnings 'redefine';

    sub Dancer::ModuleLoader::use_lib {
        1;
    }
}

use Catmandu::Sane;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat qw(:load :self);
use Catmandu::Util qw(require_package :is);
use Plack::Builder;
use Plack::App::File;
use Plack::App::Cascade;
use Dancer;
use LibreCat::App;

# setup template paths
config->{engines}{template_toolkit}{INCLUDE_PATH} = librecat->template_paths;
config->{engines}{template_toolkit}{DEBUG} //= 'provider' if config->{template_debug};

# Overwrite the default Dancer template for finding the
# template file for a view. The views_dir can be an array
# instead of a single location.
# TODO make a Dancer template engine package
{
    no warnings 'redefine';

    sub Dancer::Template::Abstract::view {
        my ($self, $view) = @_;

        my $views_dir = librecat->template_paths;

        for my $template ($self->_template_name($view)) {
            if (is_array_ref($views_dir)) {
                for my $dir (@$views_dir) {
                    my $view_path = path($dir, $template);
                    return $view_path if -f $view_path;
                }
            }
            else {
                my $view_path = path($views_dir, $template);
                return $view_path if -f $view_path;
            }
        }

        # No matching view path was found
        return;
    }
}

# setup static file serving
my $app = Plack::App::Cascade->new;
$app->add(map {Plack::App::File->new(root => $_)->to_app} @{librecat->public_paths});

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

my $uri_base = librecat->config->{uri_base} // Catmandu->config->{host} // "http://localhost:5001";

my $auth_sso = is_array_ref( $config->{auth_sso} ) ? $config->{auth_sso} : [];
my $session_sso = is_array_ref( $config->{session_sso} ) ? $config->{session_sso} : [];

builder {
    enable '+Dancer::Middleware::Rebase', base => $uri_base, strip => 0 if is_string( $uri_base );
    enable 'Deflater';
    enable 'Session',
        store => require_package( $session_store_package )->new( %$session_store_options ),
        state => require_package( $session_state_package )->new( %$session_state_options );

    for my $as ( @$auth_sso ) {

        mount $as->{path} => require_package( $as->{package}, "Plack::Auth::SSO" )->new(

            %{ $as->{options} || {} },
            uri_base => $uri_base

        )->to_app();

    }
    for my $as ( @$session_sso ) {

        mount $as->{path} => require_package( $as->{package}, "LibreCat::Auth::SSO" )->new(

            %{ $as->{options} || {} },
            uri_base => $uri_base

        )->to_app();

    }

    mount '/' => $app->to_app;
};
