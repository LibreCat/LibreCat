package LibreCat::Dedup::Publication;

use Catmandu::Sane;
use LibreCat qw(searcher);
use Moo;
use namespace::clean;

with 'LibreCat::Dedup';

sub _find_duplicate {
    my ($self, $data) = @_;

    my @q;
    push @q, "externalidentifier=$data->{isi}"  if $data->{isi};
    push @q, "externalidentifier=$data->{pmid}" if $data->{pmid};
    push @q, "doi=\"$data->{doi}\""             if $data->{doi};
    push @q, "externalidentifier=$data->{arxiv}" if $data->{arxiv};

    my $dup = searcher->search("publication",
        {cql => join(' OR ', @q), start => 0, limit => 5})->to_array;

    my @ids = map {$_->{_id}} @$dup;
    return \@ids;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Dedup::Publication - a publication deduplicator

=head1 SYNOPSIS

    use LibeCat::Dedup::Publication;

    my $detector = LibreCat::Dedup::Publication->new();

    $detector->find_duplicate({doi => "10.2393/2342wneqe"});

=head1 METHODS

=head2 has_duplicate($data)

Returns 0 or 1.

=head2 find_duplicate($data)

Returns an ARRAYREF with publication IDs.

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Dedup>

=cut
