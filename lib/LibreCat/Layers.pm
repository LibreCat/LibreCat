package LibreCat::Layers;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(read_yaml use_lib);
use Config::Onion;
use Log::Log4perl;
use Log::Any::Adapter;
use Path::Tiny;
use Moo;
use namespace::clean;

has root_path => (is => 'lazy');
has layer_paths => (is => 'lazy');
has config => (is => 'lazy', init_arg => undef);
for (qw(paths lib_paths config_paths public_paths template_paths)) {
    has $_ => (is => 'ro', init_arg => undef, default => sub {[]});
}

sub BUILD {
    my ($self, $args) = @_;

    my $root_path = $self->root_path;
    my $layer_paths = $self->layer_paths;

    for (($self->root_path, reverse @$layer_paths)) {
        my $path = path($_);
        $path = $path->absolute($self->root_path) if $path->is_relative;
        $path = $path->realpath;

        unshift @{$self->paths}, $path->stringify;

        my $view_path     = $path->child('views');
        my $template_path = $path->child('templates');
        my $public_path   = $path->child('public');
        my $config_path   = $path->child('config');
        my $lib_path      = $path->child('lib');

        if ($view_path->is_dir) {
            unshift @{$self->template_paths}, $view_path->stringify;
        } elsif ($template_path->is_dir) {
            unshift @{$self->template_paths}, $template_path->stringify;
        }

        if ($public_path->is_dir) {
            unshift @{$self->public_paths}, $public_path->stringify;
        }

        if ($config_path->is_dir) {
            unshift @{$self->config_paths}, $config_path->stringify;
        }

        if ($lib_path->is_dir) {
            unshift @{$self->lib_paths}, $lib_path->stringify;
        }
    }
}

sub load {
    my ($self) = @_;

    my $config = $self->config;
    my $lib_paths = $self->lib_paths;

    if (my $log_config = $config->{log4perl}) {
        Log::Log4perl->init(\$log_config);
        Log::Any::Adapter->set('Log4perl');
    }

    Catmandu->load($self->root_path);

    for my $key (keys %$config) {
        Catmandu->config->{$key} = $config->{$key};
    }

    if (@$lib_paths) {
        use_lib @$lib_paths;
    }

    $self;
}

sub _build_root_path {
    $ENV{LIBRECAT_ROOT} || path(__FILE__)->parent->parent->parent->stringify;
}

sub _build_layer_paths {
    my ($self) = @_;

    if ($ENV{LIBRECAT_LAYERS}) {
        [split ',', $ENV{LIBRECAT_LAYERS}];
    } elsif (path($self->root_path, 'layers.yml')->is_file) {
        read_yaml(path($self->root_path, 'layers.yml')->stringify);
    } else {
        [];
    }
}

sub _build_config {
    my ($self) = @_;

    my $config = Config::Onion->new(prefix_key => '_prefix');
    $config->load_glob(map { path($_)->child('*.yml')->stringify } reverse @{$self->config_paths});
    $config->get;
}

1;
