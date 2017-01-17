package LibreCat::Cmd;

use Catmandu::Sane;
use I18N::Langinfo qw(langinfo CODESET);
use Encode qw(decode);
use namespace::clean;

our $VERSION = '0.01';

use parent 'App::Cmd::Command';

# Internal required by App::Cmd;
sub prepare {
    my ($self, $app, @args) = @_;
    my $codeset = langinfo(CODESET);
    my @utf8_args = map { decode $codeset, $_ } @args;
    $self->SUPER::prepare($app,@utf8_args);
}

# Internal required by App::Cmd;
sub opt_spec {
    my ($class, $cli) = @_;
    (
        ['help|h|?', "print this usage screen"],
        $cli->global_opt_spec, $class->command_opt_spec($cli),
    );
}

# Internal required by App::Cmd;
sub execute {
    my ($self, $opts, $args) = @_;

    if ($opts->{help}) {
        print $self->usage->text;
        exit;
    }

    my $ret = $self->command($opts, $args) // 2;

    exit($ret) if $ret != 0;
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
