package LibreCat::Logger;

use Catmandu::Sane;
use Log::Any ();
use Moo::Role;
use namespace::clean;

has log => (is => 'lazy');

sub _build_log {
    Log::Any->get_logger(category => ref $_[0]);
}

1;

__END__

=pod

=head1 NAME

LibreCat::Logger - a logger for LibreCat modules

=head1 SYNOPSIS

    package MyPackage;

    use Moo;

    with "LibreCat::Logger";

    sub demo {
        my ($self, $data) = @_;

        $self->log->debug("Executing sub demo in MyPackage");
    }

=head1 SEE ALSO

L<LibreCat>, L<Log::Any>, L<config/log4perl.yml>

=cut
