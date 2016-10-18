#!/usr/bin/env perl

my $layers;

BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    $layers = LibreCat::Layers->new->load;

    use Dancer::ModuleLoader;

    # TODO very dirty, this prevents Dancer from prepending lib/ in @INC
    {
        no warnings 'redefine';

        sub Dancer::ModuleLoader::use_lib {
            1;
        }
    }
};

use Catmandu::Sane;
use Catmandu::Util qw(require_package :is);
use Plack::Builder;
use Plack::App::File;
use Plack::App::Cascade;
use Dancer;
use LibreCat::App;
use Data::Dumper;

# setup template paths
config->{engines}{template_toolkit}{INCLUDE_PATH} = $layers->template_paths;
config->{engines}{template_toolkit}{DEBUG} //= 'provider' if config->{template_debug};

# Overwrite the default Dancer template for finding the
# template file for a view. The views_dir can be an array
# instead of a single location.
# TODO make a Dancer template engine package
{
    no warnings 'redefine';

    sub Dancer::Template::Abstract::view {
        my ($self, $view) = @_;

        my $views_dir = $layers->template_paths;

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

# check if one created a local configuration or a layers
unless (exists $config->{authentication} && exists $config->{user}) {
    die <<EOF;
Oops! You didn't create a local configuration file or the local layer
containing a local configuration wasn't found. No definitions found
for 'authentication' and 'user'.

Check: did you create a config/catmandu.local.yml file?
EOF
}

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
