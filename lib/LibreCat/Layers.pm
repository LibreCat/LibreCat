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

__END__

=pod

=head1 NAME

LibreCat::Layers - A mechanism to load custom config, templates, assets and code on top of LibreCat

=head1 SYNOPSIS

    use LibreCat::Layers;
    my $layers = LibreCat::Layers->new;
    my $config = $layers->config;
    $layers->load;

The L<LibreCat> web application, commandline tool and tests are already layers aware.

=head1 DESCRIPTION

This module provides a mechanism to load configuration, templates, static
assets and code to customize the stock L<LibreCat> application. All you need to
do is write a C<layers.yml> configuration file at the root of the application
listing the directories where L<LibreCat> can find your customizations.

This is a sample C<layers.yml> file with 2 customization layers:

    - /path/to/layer2
    - /path/to/layer1

C<layer2> will override C<layer1> which will in turn override the stock
application.

Relative paths to layers are searched from the root of the application.

=head1 LAYER STRUCTURE

Custom YAML configuration files can be placed in a B<config> directory.

Custom templates can be placed in either a B<views> or B<templates> directory.

Custom static assets can be placed in a B<public> directory.

Custom code can be placed in a B<lib> directory.

=head1 ENVIRONMENT VARIABLES

You can also configure layers through the C<LIBRECAT_LAYERS> environment
variable, in which case the C<layers.yml> file will be ignored.

    LIBRECAT_LAYERS=/path/to/layer2,/path/to/layer1 bin/librecat

=head1 METHODS

=head2 new

=head3 PARAMETERS

=over

=item root_path

=item layer_paths

=back

=head2 root_path

=head2 layer_paths

=head2 paths

=head2 lib_paths

=head2 config_paths

=head2 public_paths

=head2 template_paths

=head2 config

=cut

