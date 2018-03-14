package LibreCat::Cmd::index;

use Catmandu::Sane;
use LibreCat::JobQueue;
use LibreCat::Index;
use Fcntl qw(:flock);
use File::Spec;
use parent qw(LibreCat::Cmd);
use Carp;

sub description {
    return <<EOF;
Usage:
librecat index initialize
librecat index create BAG
librecat index drop BAG
librecat index purge
librecat index status
librecat index switch
EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (['yes!', ""]);
}

sub opts {
    state $opts = $_[1];
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands = qr/initialize|status|create|drop|purge|switch/;

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    if ($cmd eq 'create') {
        return $self->_create(@$args);
    }
    elsif ($cmd eq 'drop') {
        return $self->_drop(@$args);
    }
    elsif ($cmd eq 'purge') {
        return $self->_purge(@$args);
    }
    elsif ($cmd eq 'status') {
        return $self->_status(@$args);
    }
    elsif ($cmd eq 'initialize') {
        my $start;
        print
            "Use this command during installation only.\nThis command will delete existing indices!\nAre you sure you want to run it [y/N]:";

        if ($opts->{yes}) {
            $start = 'y';
        }
        else {
            $start = <STDIN>;
            chomp($start);
        }
        if (lc $start eq 'y') {
            return $self->_initialize(@$args);
        }
        else {
            print STDERR "Command initialize has been cancelled\n";
        }
    }
    elsif ($cmd eq 'switch') {
        return $self->_switch(@$args);
    }
}

sub _create {
    my ($self, $name) = @_;

    croak "need a bag" unless $name;

    my $main_store = Catmandu->store('main');
    my $store      = Catmandu->store('search');

    my $bag = $store->bag($name);
    $bag->add_many($main_store->bag($name)->benchmark);
    $bag->commit;

    return 0;
}

sub _drop {
    my ($self, $name) = @_;

    croak "need a bag" unless $name;

    my $store = Catmandu->store('search');
    my $bag   = $store->bag($name);
    $bag->delete_all;
    $bag->commit;

    return 0;
}

sub _status {
    my ($self) = @_;
    my $status = LibreCat::Index->new->get_status;
    Catmandu->exporter('YAML')->add($status);
    return 0;
}

sub _initialize {
    my ($self) = @_;
    defined(LibreCat::Index->new->initialize) ? 0 : 1;
}

sub _switch {
    my ($self) = @_;
    my $pidfile
        = File::Spec->catfile(File::Spec->tmpdir, "librecat.index.lock");

    open my $file, ">", $pidfile || die "Failed to create $pidfile: $!";
    flock($file, LOCK_EX | LOCK_NB) || die "Running more than one indexer?";

    defined(LibreCat::Index->new->switch) ? 0 : 1;
}

sub _purge {
    my ($self) = @_;
    defined(LibreCat::Index->new->remove_all) ? 0 : 1;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::index - manage index jobs

=head1 SYNOPSIS

    librecat index initialize
    librecat index create BAG
    librecat index drop BAG
    librecat index purge
    librecat index status
    librecat index switch

=cut
