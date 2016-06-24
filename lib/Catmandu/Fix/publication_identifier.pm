package Catmandu::Fix::publication_identifier;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $data) = @_;

    if ($data->{publication_identifier}
        and ref $data->{publication_identifier} eq "ARRAY") {
        my $publid_hash;
        foreach my $publid (@{$data->{publication_identifier}}) {
            $publid->{type} = 'unknown' unless $publid->{type} && length $publid->{type};
            $publid_hash->{$publid->{type}} = []
                if !$publid_hash->{$publid->{type}};
            push @{$publid_hash->{$publid->{type}}}, $publid->{value};
        }
        delete $data->{publication_identifier};
        $data->{publication_identifier} = $publid_hash if $publid_hash;
    }

    return $data;
}

1;

__END__

=pod

=head1 NAME

Catmandu::Fix::publication_identifier - transform publication_identifier array into a hash

=head1 SYNOPSIS

    publication_identifier()

=cut
