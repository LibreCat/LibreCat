package LibreCat::CLI;

use Catmandu::Sane;

use parent 'App::Cmd';

sub plugin_search_path { 'LibreCat::Cmd' }

sub global_opt_spec {
    (
    );
}

1;

__END__

=pod

=head1 NAME

LibreCat::CLI - The App::Cmd application class for the librecat command line app

=cut
