package LibreCat;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use String::CamelCase qw(camelize);
use Data::Util qw(install_subroutine);
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
        my ($self, @args) = @_;
        $self->_load(@args) unless $self->loaded;
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

sub models {
    [qw(publication department research_group user project)];
}

sub install_models {
    my ($self) = @_;
    my $models = $self->models;
    for my $name (@$models) {
        my $config   = $self->config->{$name} // {};
        my $pkg_name = camelize($name);
        my $pkg      = require_package($pkg_name, 'LibreCat::Model');
        my $validator_pkg
            = require_package('LibreCat::Validator::JSONSchema');
        my $validator
            = $validator_pkg->new(schema => $self->config->{schemas}{$name});
        my $model = $pkg->new(
            bag        => Catmandu->store('main')->bag($name),
            search_bag => Catmandu->store('search')->bag($name),
            validator  => $validator,
            %$config,
        );
        install_subroutine(__PACKAGE__, $name => sub {$model});
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

sub searcher {
    state $searcher = require_package('LibreCat::Search')
        ->new(store => Catmandu->store('search'));
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
