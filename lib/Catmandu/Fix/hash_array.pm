package Catmandu::Fix::hash_array;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use LibreCat::App::Helper;
use Moo;

has 'array_fields' => (is => 'lazy');

sub _build_array_fields {
    my $self = $_[0];
    my $arr  = h->config->{forms}->{array_field} // [];

    my %lookup = map { $_ => 1 } @$arr;
    \%lookup;
}

sub fix {
    my ($self, $data) = @_;

    # Validating the publiction keys. If in the configuration file
    # they are defined as arrays, forces them to be arrays.
    foreach my $key (keys %$data) {
        my $ref           = ref($data->{$key});

        if ($ref eq "ARRAY" and ! $self->array_fields->{$key}) {
            $data->{$key} = $data->{$key}->[0];
        }
        elsif ($ref ne "ARRAY" and $self->array_fields->{$key}) {
            $data->{$key} = [$data->{$key}];
        }
        else {
            # ok
        }
    }

    return $data;
}

1;
