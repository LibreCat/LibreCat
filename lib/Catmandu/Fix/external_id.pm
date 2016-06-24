package Catmandu::Fix::external_id;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $data) = @_;

    if ($data->{external_id} and ref $data->{external_id} eq "ARRAY") {
        my $extid_hash;
        foreach my $extid (@{$data->{external_id}}) {
            $extid->{type} = 'unknown' unless $extid->{type} && length $extid->{type};
            next if $extid_hash->{$extid->{type}};
            $extid_hash->{$extid->{type}} = $extid->{value};
        }
        delete $data->{external_id};
        $data->{external_id} = $extid_hash;
    }

    return $data;
}

1;

__END__

=pod

=head1 NAME

Catmandu::Fix::external_id - transform external_id array into a hash

=head1 SYNOPSIS

    # Transform an array of external_ids into a uniq list of hashes
    # external_id:
    #    - type: opac
    #      value: 12345
    #    - type: opac
    #      value: 6789   (copy)
    #    - type: arxiv
    #      value: 0001

    external_id()

    # external_id:
    #      opac: 12345
    #      arxiv: 0001

=cut
