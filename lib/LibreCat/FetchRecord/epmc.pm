package LibreCat::FetchRecord::epmc;

use Catmandu::Util qw(:io);
use Moo;
use Dancer qw(:syntax);

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    $id =~ s/^\D+(\d+)/$1/i;

    $self->log->debug("requesting $id from epmc");

    my $data = Catmandu->importer(
        'EuropePMC',
        query => $id,
        fix   => [join_path('fixes', 'epmc_mapping.fix')],
    )->first;

    my $fixer = $self->create_fixer('epmc_mapping.fix');

    $data = $fixer->fix($data);

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::epmc - Create a LibreCat publication based on a PubMed id

=head1 SYNOPSIS

    use LibreCat::FetchRecord::epmc;

    my $pub = LibreCat::FetchRecord::epmc->new->fetch('27740824');

=cut
