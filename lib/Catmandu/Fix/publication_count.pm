package Catmandu::Fix::publication_count;

=pod

=head1 NAME

Catmandu::Fix::publication_count - add a 'publication_count' field calculated from the user data

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat qw(searcher);
use Moo;

sub fix {
    my ($self, $data) = @_;

    my $id  = $data->{_id};
    my $pub = searcher->search('publication',
        {cql => ["person=$id", "status=public"], start => 0, limit => 1});

    if (is_number($pub->{total}) && $pub->{total} > 0) {
        $data->{publication_count} = $pub->{total};
    }

    $data;
}

1;
