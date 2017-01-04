package LibreCat;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use LibreCat::Layers;
use LibreCat::Hook;
use Catmandu;
use namespace::clean;

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
        $layers ||= LibreCat::Layers->new(@args)->load;
        $self;
    }

    sub config {
        $_[0]->check_loaded;
        Catmandu->config;
    }
}

sub user {
    state $user = require_package('LibreCat::User')->new($_[0]->config->{user});
}

sub hook {
    my ($self, $name) = @_;

    state $hooks = {};

    $hooks->{$name} ||= do {
        my $args = {before_fixes => [], after_fixes => []};

        my $hook = ($self->config->{hooks} || {})->{$name} || {};

        for my $key (qw(before_fixes after_fixes)) {
            my $fixes = $hook->{$key} || [];
            for my $fix (@$fixes) {
                push @{$args->{$key}},
                    require_package($fix, 'LibreCat::Hook')->new( name => $name , type => $key );
            }
        }

        LibreCat::Hook->new($args);
    };
}

sub searcher {
    state $searcher = require_package('LibreCat::Search')->new(store => Catmandu->store('search'));
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
   #      before_fixes: [BeforeFix1,BeforeFix2]
   #      after_fixes:  [AfterFix]

   my $hook = LibreCat->hook('eat');

   $hook->fix_before($data);  # BeforeFix1->fix($data) and
                              # BeforeFix2->fix($data) will be executed
   $hook->fix_after($data);   # AfterFix->fix($data) will be executed

=cut
