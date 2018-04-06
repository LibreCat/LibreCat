package LibreCat;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use String::CamelCase qw(camelize);
use Data::Util qw(install_subroutine);
use POSIX qw(strftime);
use LibreCat::Layers;
use LibreCat::Hook;
use Catmandu;
use namespace::clean;

our $VERSION = '0.3.2';

sub import {
    my $self = shift;
    my $load = shift;
    if ($load && $load =~ /^:?load$/) {
        $self->load(@_);
    }
}

{
    my $layers;

    sub check_loaded {
        $layers || Catmandu::Error->throw("LibreCat must be loaded first");
    }

    sub layers {
        $_[0]->check_loaded;
    }

    sub loaded {
        $layers ? 1 : 0;
    }

    sub load {
        my $self = shift;
        $self->_load(@_) unless $self->loaded;
        $self;
    }

    sub _load {
        my ($self, @args) = @_;
        $layers = LibreCat::Layers->new(@args)->load;
        $self->install_models;
    }

    sub config {
        $_[0]->check_loaded;
        Catmandu->config;
    }
}

# TODO this duplicates LibreCat::Logger
sub log {
    state $log = Log::Log4perl::get_logger($_[0]);
}

sub model_names {
    [qw(publication department research_group user project)];
}

sub install_models {
    my ($self) = @_;
    my $names = $self->model_names;
    for my $name (@$names) {
        my $config         = $self->config->{$name} // {};
        my $bag            = Catmandu->store('main')->bag($name),
            my $search_bag = Catmandu->store('search')->bag($name),
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
        my $model        = $pkg->new(
            bag               => $bag,
            search_bag        => $search_bag,
            validator         => $validator,
            append_before_add => [update_fixer => $update_fixer],
            %$config,
        );
        install_subroutine($self, $name => sub {$model});
    }
}

sub hook {
    my ($self, $name) = @_;

    $name // Catmandu::Error->throw("need a name");

    state $hooks = {};

    $hooks->{$name} ||= do {
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

        LibreCat::Hook->new($args);
    };
}

sub fixer {
    my ($self, $file) = @_;

    $self->log->debug("searching for fix '$file'");

    for my $path (@{$self->layers->fixes_paths}) {
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

sub searcher {
    state $searcher = require_package('LibreCat::Search')
        ->new(store => Catmandu->store('search'));
}

sub timestamp {
    my $time = $_[1] // time;
    my $time_format = $_[0]->config->{time_format} // '%Y-%m-%dT%H:%M:%SZ';
    my $now = strftime($time_format, gmtime($time));
    $now;
}

sub queue {
    state $queue = require_package('LibreCat::JobQueue')->new;
}

1;

__END__

=pod

=head1 NAME

LibreCat - Librecat helper functions

=head1 SYNOPSIS

   use LibreCat;

   # Given a 'catmandu' configuration file, like: catmandu.hooks.yml
   # --
   # hooks:
   #   myhook:
   #      options:
   #        foo: bar
   #      before_fixes: [BeforeFix1,BeforeFix2]
   #      after_fixes:  [AfterFix]

   my $hook = LibreCat->hook('eat');

   $hook->fix_before($data);  # BeforeFix1->fix($data) and
                              # BeforeFix2->fix($data) will be executed
   $hook->fix_after($data);   # AfterFix->fix($data) will be executed

=head1 LICENSE AND COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See L<http://dev.perl.org/licenses/> for more information.

=cut
