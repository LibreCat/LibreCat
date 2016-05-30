package LibreCat::Cmd;

use Catmandu::Sane;

our $VERSION = '0.01';

use parent 'App::Cmd::Command';

sub opt_spec {
    my ($class, $cli) = @_;
    (
        ['help|h|?', "print this usage screen"],
        $cli->global_opt_spec, $class->command_opt_spec($cli),
    );
}

sub execute {
    my ($self, $opts, $args) = @_;

    if ($opts->{version}) {
        print $VERSION;
        exit;
    }
    if ($opts->{help}) {
        print $self->usage->text;
        exit;
    }

    $self->command($opts, $args);
}

# these should be implemented by the LibreCat::Cmd's
sub command_opt_spec { }
sub command          { }

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd - A base class for extending the librecat command line app

=cut
