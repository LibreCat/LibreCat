package Catmandu::Fix::person;

=pod

=head1 NAME

Catmandu::Fix::person - generate a full_name if not exists

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Moo;

sub fix {
    my ($self, $data) = @_;
    my @types = qw(author editor translator supervisor corporate_editor applicant);

    foreach my $author_type (@types) {
        next unless $data->{$author_type};
        foreach my $au (@{$data->{$author_type}}) {
            if (is_string($au->{full_name})) {
                # ok
            }
            elsif (is_string($au->{first_name}) && is_string($au->{last_name})) {
                $au->{full_name} = $au->{last_name} . ", " . $au->{first_name};
            }
        }
    }

    return $data;
}

1;
