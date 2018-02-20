package LibreCat::Cmd::repl;

use Catmandu::Sane;
use Devel::REPL;
use parent 'LibreCat::Cmd';

sub command_opt_spec {
    ();
}

sub description {
    return <<EOF;
Usage:

librecat repl

Install rlwrap for a better experience with support for line editing and
history:

rlwrap librecat repl

EOF
}

sub command {
    my ($self, $opts, $args) = @_;

    my @plugins = qw(
       Colors
       DDC
       History
       LexEnv
       MultiLine::PPI
       FancyPrompt
    );

    my $init = <<PERL;
    use Catmandu::Sane;
    use Catmandu;
    use LibreCat;
PERL

    my $repl = Devel::REPL->new;
    $repl->load_plugin($_) for @plugins;
    $repl->eval($init);
    $repl->run;

}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::repl - Interactive perl shell for librecat

=cut


