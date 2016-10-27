package LibreCat;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use LibreCat::Layers;
use LibreCat::Hook;
use LibreCat::User;
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
        defined $layers;
    }

    sub load {
        my ($self, @args) = @_;
        $layers ||= LibreCat::Layers->new(@args)->load;
        $self;
    }

    sub config {
        state $config = $_[0]->layers->config;
    }
}

sub hook {
    my ($self, $name) = @_;
    state $hooks = {};
    $hooks->{$name} ||= do {
        my $args = {before_fixes => [], after_fixes => [],};

        my $hook = ($self->config->{hooks} || {})->{$name} || {};
        for my $key (qw(before_fixes after_fixes)) {
            my $fixes = $hook->{$key} || [];
            for my $fix (@$fixes) {
                push @{$args->{$key}},
                    require_package($fix, 'LibreCat::Hook')->new;
            }
        }

        LibreCat::Hook->new($args);
    };
}

sub user {
    state $user = do {
        my $config = $self->config->{user};
        LibreCat::User->new($config);
    };
}

sub auth {
    state $auth = do {
        my $pkg = require_package($self->config->{authentication}->{package});
        $pkg->new($self->config->{authentication}->{options} // {});
    };
}

1;

__END__

=pod

=head1 NAME

LibreCat - Librecat helper functions

=head1 SYNOPSIS

    use LibreCat;

    # given a configuration file like hooks.yml:
    # --
    # hooks:
    #   myhook:
    #      before_fixes: [BeforeFix1,BeforeFix2]
    #      after_fixes:  [AfterFix]

    my $hook = LibreCat->hook('eat');

    $hook->fix_before($data);  # BeforeFix1->fix($data) and
                               # BeforeFix2->fix($data) will be executed
    # do stuff ...
    $hook->fix_after($data);   # AfterFix->fix($data) will be executed

    # more concise:
    $hook->fix_around($data, sub {
        # do stuff ...
    });

=cut
