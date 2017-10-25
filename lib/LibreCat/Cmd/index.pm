package LibreCat::Cmd::index;

use Catmandu::Sane;
use LibreCat::JobQueue;
use LibreCat::Index;
use parent qw(LibreCat::Cmd);
use Carp;

sub description {
    return <<EOF;
Usage:
librecat index initialize
librecat index create BAG
librecat index drop BAG
librecat index status
librecat index switch
EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (['background|bg', ""], ['id=s', ""], );
}

sub opts {
    state $opts = $_[1];
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands = qr/initialize|status|create|drop|switch/;

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
    elsif ($cmd eq 'status') {
        return $self->_status(@$args);
    }
    elsif ($cmd eq 'initialize') {
        print "Use this command during installation only.\nThis command will delete existing indices!\nAre you sure you want to run it [y/N]:";
        my $start = <STDIN>;
        chomp($start);
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
    my ($self,$name) = @_;

    croak "need a bag" unless $name;

    my $main_store = Catmandu->store('main');
    my $store      = Catmandu->store('search');

    my $bag = $store->bag($name);
    $bag->add_many($main_store->bag($name)->benchmark);
    $bag->commit;
}

sub _drop {
    my ($self,$name) = @_;

    croak "need a bag" unless $name;

    my $store = Catmandu->store('search');
    my $bag   = $store->bag($name);
    $bag->delete_all;
    $bag->commit;
}

sub _status {
    my ($self) = @_;
    my $status = LibreCat::Index->get_status;
    Catmandu->exporter('YAML')->add($status);
}

sub _initialize {
    my ($self) = @_;
    LibreCat::Index->initialize;
}

sub _switch {
    my ($self) = @_;
    LibreCat::Index->switch;
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
    librecat index status
    librecat index switch

=cut
