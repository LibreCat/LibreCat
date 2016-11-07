package LibreCat::FetchRecord::inspire;

use Catmandu::Util qw(:io);
use Moo;

with 'LibreCat::FetchRecord';

sub fetch {
    my ($self, $id) = @_;

    $self->log->debug("requesting $id from inspire");

    my $data = Catmandu->importer(
        'Inspire',
        id  => $id,
        fix => [join_path('fixes', 'inspire_mapping.fix')],
    )->first;

    my $fixer = $self->create_fixer('inspire_mapping.fix');

    $data = $fixer->fix($data);

    $data;
}

1;
