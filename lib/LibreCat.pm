package LibreCat;

use Catmandu::Sane;

our $VERSION = '0.3.2';

use Config::Onion;
use Log::Log4perl;
use Log::Any::Adapter;
use Path::Tiny;
use Catmandu::Util qw(is_ref require_package use_lib read_yaml);
use List::MoreUtils qw(any);
use String::CamelCase qw(camelize);
use POSIX qw(strftime);
use LibreCat::Hook;
use Catmandu::Fix;
use Catmandu;
use Exporter::Shiny;
use Moo;
use Autoload::AUTOCAN;
use namespace::clean -except => 'AUTOLOAD';

# class methods (load and access singleton)

{
    my $instance;

    sub instance {
        $instance || Catmandu::Error->throw("LibreCat must be loaded first");
    }

    sub loaded {
        $instance ? 1 : 0;
    }

    sub load {
        $instance ||= do {
            my $class = shift;
            $class->new(@_);
        };
    }
}

# configure exporter

sub _exporter_expand_tag {
    my ($class, $name, $args, $globals) = @_;

    if ($name eq 'load') {
        $class->load($args // {});
        return;
    }
    if ($name eq 'self') {
        return [librecat => {}], [l => {}];
    }

    $class->SUPER::_exporter_expand_tag($name, $args, $globals);
}

sub _exporter_expand_sub {
    my ($class, $name, $args, $globals) = @_;

    if (any { $_ eq $name } qw(librecat l)) {
        return $name => sub { state $memo = $class->instance };
    }
    if (any { $_ eq $name } qw(log config fixer hook queue model root_path searcher timestamp)) {
        return $name => sub { state $memo = $class->instance; $memo->$name(@_) };
    }
    if ($class->instance->has_model($name)) {
        return $name => sub { state $memo = $class->instance->model($name) };
    }

    $class->SUPER::_exporter_expand_sub($name, $args, $globals);
}

# auto model accessors

sub AUTOCAN {
    my ($self, $method) = @_;
    # Backwards compatibility with the old user class method
    if (!is_ref($self) && $method eq 'user') {
        $self = $self->instance;
        $self->log->warn(
            "DEPRECATION NOTICE: calling user as a class method is deprecated."
        );
    }
    $self->has_model($method) || return;
    $self->_model_accessors->{$method} //= do {
        my $model = $self->model($method);
        sub { $model };
    };
}

# instance methods

with 'LibreCat::Logger';

has root_path   => (is => 'lazy');
has layer_paths => (is => 'lazy');
has config      => (is => 'lazy');
has css_paths   => (is => 'lazy', init_arg => undef);
has paths => (is => 'ro', init_arg => undef, default => sub {[]});
has lib_paths => (is => 'ro', init_arg => undef, default => sub {[]});
has config_paths => (is => 'ro', init_arg => undef, default => sub {[]});
has public_paths => (is => 'ro', init_arg => undef, default => sub {[]});
has scss_paths => (is => 'ro', init_arg => undef, default => sub {[]});
has template_paths => (is => 'ro', init_arg => undef, default => sub {[]});
has fixes_paths => (is => 'ro', init_arg => undef, default => sub {[]});
has models => (is => 'lazy');
has _model_instances => (is => 'ro', init_arg => undef, default => sub {+{}});
has _model_accessors => (is => 'ro', init_arg => undef, default => sub {+{}});
has _hook_instances => (is => 'ro', init_arg => undef, default => sub{+{}});
has searcher => (is => 'lazy');
has queue => (is => 'lazy');

sub BUILD {
    my ($self) = @_;

    $self->_setup_paths;
    $self->_setup_logging;
    $self->_setup_catmandu;
    $self->_setup_lib;
}

sub _build_root_path {
    $ENV{LIBRECAT_ROOT} || path(__FILE__)->parent->parent->absolute->stringify;
}

sub _build_layer_paths {
    my ($self) = @_;

    if ($ENV{LIBRECAT_LAYERS}) {
        [split ',', $ENV{LIBRECAT_LAYERS}];
    }
    elsif (path($self->root_path, 'layers.yml')->is_file) {
        read_yaml(path($self->root_path, 'layers.yml')->stringify) // [];
    }
    else {
        [];
    }
}

sub _build_css_paths {
    my ($self) = @_;

    [map {$_->stringify}
        grep {$_->is_dir}
        map  {path($_)->child('css')} @{$self->public_paths}];
}

sub _build_config {
    my ($self) = @_;

    my $config = Config::Onion->new(prefix_key => '_prefix');
    $config->load_glob(map {path($_)->child('*.yml')->stringify}
            reverse @{$self->config_paths});
    $config->get;
}

sub _setup_paths {
    my ($self) = @_;

    my $root_path   = $self->root_path;
    my $layer_paths = $self->layer_paths;

    for (($self->root_path, reverse @$layer_paths)) {
        my $path = path($_);
        $path = $path->absolute($self->root_path) if $path->is_relative;
        $path = $path->realpath;

        unshift @{$self->paths}, $path->stringify;

        my $config_path   = $path->child('config');
        my $lib_path      = $path->child('lib');
        my $public_path   = $path->child('public');
        my $scss_path     = $path->child('scss');
        my $template_path = $path->child('templates');
        my $view_path     = $path->child('views');
        my $fixes_path    = $path->child('fixes');

        if ($config_path->is_dir) {
            unshift @{$self->config_paths}, $config_path->stringify;
        }

        if ($lib_path->is_dir) {
            unshift @{$self->lib_paths}, $lib_path->stringify;
        }

        if ($public_path->is_dir) {
            unshift @{$self->public_paths}, $public_path->stringify;
        }

        if ($scss_path->is_dir) {
            unshift @{$self->scss_paths}, $scss_path->stringify;
        }

        if ($view_path->is_dir) {
            unshift @{$self->template_paths}, $view_path->stringify;
        }
        elsif ($template_path->is_dir) {
            unshift @{$self->template_paths}, $template_path->stringify;
        }

        if ($fixes_path->is_dir) {
            unshift @{$self->fixes_paths}, $fixes_path->stringify;
        }
    }
}

sub _setup_logging {
    my ($self) = @_;

    if (my $log_config = $self->config->{log4perl}) {
        Log::Log4perl->init(\$log_config);
        Log::Any::Adapter->set('Log4perl');
    }
}

sub _setup_catmandu {
    my ($self) = @_;

    # TODO Catmandu should accept config in load so that
    # there is no reload of the environment
    Catmandu->load($self->root_path);
    Catmandu->config($self->config);
}

sub _setup_lib {
    my ($self) = @_;

    my $lib_paths = $self->lib_paths;
    if (@$lib_paths) {
        use_lib @$lib_paths;
    }
}

# TODO load from config
sub _build_models {
    [qw(publication department research_group user project)];
}

sub _new_model {
    my ($self, $name) = @_;

    Catmandu::BadArg->throw("Unknown model '$name'") unless $self->has_model($name);

    my $config     = $self->config->{$name} // {};
    my $bag        = Catmandu->store('main')->bag($name);
    my $search_bag = Catmandu->store('search')->bag($name);
    my $pkg_name   = camelize($name);
    my $pkg = require_package($pkg_name, 'LibreCat::Model');
    if ($bag->does('Catmandu::Plugin::Versioning')) {
        $pkg = $pkg->with_plugins('Versioning');
    }
    my $validator_pkg
        = require_package('LibreCat::Validator::JSONSchema');
    my $validator
        = $validator_pkg->new(schema => $self->config->{schemas}{$name});
    my $update_fixer = $self->fixer("update_${name}.fix");
    my $index_fixer = $self->fixer("index_${name}.fix");

    $pkg->new(
        bag                 => $bag,
        search_bag          => $search_bag,
        validator           => $validator,
        append_before_add   => [update_fixer => $update_fixer],
        append_before_index => [index_fixer  => $index_fixer],
        %$config,
    );
}

sub has_model {
    my ($self, $name) = @_;
    any { $_ eq $name } @{$self->models};
}

sub model {
    my ($self, $name) = @_;
    $self->_model_instances->{$name} //= $self->_new_model($name);
}

sub _new_hook {
    my ($self, $name) = @_;

    $name // Catmandu::Error->throw("need a name");

    my $args = {before_fixes => [], after_fixes => []};

    my $hook = ($self->config->{hooks} || {})->{$name} || {};

    my $hook_options = $hook->{options} || {};

    for my $key (qw(before_fixes after_fixes)) {
        my $fixes = $hook->{$key} || [];
        for my $fix (@$fixes) {
            push @{$args->{$key}},
                require_package($fix, 'LibreCat::Hook')
                ->new(%$hook_options, name => $name, type => $key);
        }
    }

    require_package('LibreCat::Hook')->new($args);
}

sub hook {
    my ($self, $name) = @_;

    $self->_hook_instances->{$name} ||= $self->_new_hook($name);
}

sub fixer {
    my ($self, $file) = @_;

    $self->log->debug("searching for fix '$file'");

    for my $path (@{$self->fixes_paths}) {
        $self->log->debug("testing '$path/$file'");
        if (-r "$path/$file") {
            $self->log->debug("found '$path/$file'");
            return Catmandu::Fix->new(fixes => ["$path/$file"]);
        }
    }

    $self->log->error("can't find a fixer for '$file'");

    # TODO this should throw an error and not be called at all if there is no
    # fix
    Catmandu::Fix->new;
}

sub _build_searcher {
    require_package('LibreCat::Search')
        ->new(store => Catmandu->store('search'));
}

sub _build_queue {
    require_package('LibreCat::JobQueue')->new;
}

sub timestamp {
    my ($self, $time) = @_;
    $time //= time;
    my $time_format = $self->config->{time_format} // '%Y-%m-%dT%H:%M:%SZ';
    my $now = strftime($time_format, gmtime($time));
    $now;
}

# Backwards compatibility with the old layers class method
# (layers functionality has been merged into this package)
sub layers {
    my ($self) = @_;
    $self = $self->instance unless is_ref($self);
    $self->log->warn(
        "DEPRECATION NOTICE: layers method is deprecated. All it's methods are available in the LibreCat instance."
    );
    $self;
}

# Backwards compatibility with the old config, hook and searcher class methods
for my $method (qw(config hook searcher)) {
    around $method => sub {
        my $orig = shift;
        my $self = shift;
        unless (is_ref($self)) {
            $self = $self->instance;
            $self->log->warn(
                "DEPRECATION NOTICE: calling $method as a class method is deprecated."
            );
        }
        $orig->($self, @_);
    };
}

1;

__END__

=pod

=head1 NAME

LibreCat - LibreCat configuration and state

=head1 SYNOPSIS

   use LibreCat qw(:self);
   librecat->model('publication')->add($rec);
   # l is a shortcut for librecat
   l->model('publication')->add($rec);
   # even shorter but slower
   l->publication->add($rec);

   # shortest and fastest
   use LibreCat qw(publication);
   publication->add($rec);

   # without importing
   use LibreCat;
   LibreCat->instance->model('publication');

   # Given this configuration file, like: config/hooks.yml
   # --
   # hooks:
   #   myhook:
   #      options:
   #        foo: bar
   #      before_fixes: [BeforeFix1,BeforeFix2]
   #      after_fixes:  [AfterFix]

   use LibreCat qw(hook);
   my $hook = hook('eat');

   $hook->fix_before($data);  # BeforeFix1->fix($data) and
                              # BeforeFix2->fix($data) will be executed
   $hook->fix_after($data);   # AfterFix->fix($data) will be executed

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

You can also configure LibreCat layers through the C<LIBRECAT_LAYERS> environment
variable, in which case the C<layers.yml> file will be ignored.

    LIBRECAT_LAYERS=/path/to/layer2,/path/to/layer1 bin/librecat

=head1 EXPORTED FUNCTIONS

=head1 CONFIGURATION

=head2 root_path

=head2 layer_paths

=head1 METHODS

=head2 config

=head2 models

=head2 has_model($name)

=head2 model($name)

=head2 searcher

=head2 queue

=head2 hook

=head2 fixer

=head2 timestamp($time)

=head2 root_path

=head2 layer_paths

=head2 css_paths

=head2 config

=head2 config_paths

=head2 lib_paths

=head2 layer_paths

=head2 paths

=head2 public_paths

=head2 root_path

=head2 scss_paths

=head2 template_paths

=head1 LICENSE AND COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut
