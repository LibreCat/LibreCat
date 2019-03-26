package LibreCat::FetchRecord::wos;

use Catmandu::Util qw(:io);
use LibreCat -self;
use Moo;
use Dancer qw(:syntax);

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $ris) = @_;

    $self->log->debug("parsing WOS data: $ris");

    my $fixer = librecat->fixer('wos_mapping.fix');

    my $data
        = $fixer->fix(Catmandu->importer('RIS', file => \$ris))->to_array;

    unless (@$data) {
        $self->log->error("failed to import data from $ris");
        return ();
    }

    return $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::wos - Create LibreCat publications from a WoS file

=head1 SYNOPSIS

    use LibreCat::FetchRecord::wos;

    my $records = LibreCat::FetchRecord::wos->new->fetch($wos_file);

=head1 SEE ALSO

L<LibreCat::FetchRecord>

=cut
