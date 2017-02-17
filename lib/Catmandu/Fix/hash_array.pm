package Catmandu::Fix::hash_array;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use LibreCat::App::Helper;
use Moo;

has 'array_fields' => (is => 'lazy');

sub _build_array_fields {
    my $self  = $_[0];
    my $lookup = {};
    my $forms = h->config->{forms}->{publication_types};

    for my $pub_type (keys %$forms) {
        my $basic_fields     = $forms->{$pub_type}->{fields}->{basic_fields};
        my $file_upload      = $forms->{$pub_type}->{fields}->{file_upload};
        my $supplementary_fields = $forms->{$pub_type}->{fields}->{supplementary_fields};
        my $related_material = $forms->{$pub_type}->{fields}->{related_material};

        for my $field (keys %$basic_fields) {
            my $multiple = $basic_fields->{$field}->{multiple} // 0;
            $lookup->{$pub_type}->{$field} = $multiple;
        }

        $lookup->{$pub_type}->{file} = 1;

        for my $field (keys %$supplementary_fields) {
            my $multiple = $supplementary_fields->{$field}->{multiple} // 0;
            $lookup->{$pub_type}->{$field} = $multiple;
        }

        for my $field (keys %$related_material) {
            my $multiple = $related_material->{$field}->{multiple} // 0;
            $lookup->{$pub_type}->{$field} = $multiple;
        }
    }

    $lookup;
}

sub fix {
    my ($self, $data) = @_;

    my $array_fields = $self->array_fields;
    my $pub_type     = $data->{type} // 'other';

    # Validating the publiction keys. If in the configuration file
    # they are defined as arrays, forces them to be arrays.
    foreach my $key (keys %$data) {
        my $ref = ref($data->{$key});

        my $multiple = $array_fields->{$pub_type}->{$key};

        next unless defined($multiple);
        
        if ($ref eq "ARRAY" && $multiple == 0) {
            $data->{$key} = $data->{$key}->[0];
        }
        elsif ($ref ne "ARRAY" && $multiple == 1) {
            $data->{$key} = [$data->{$key}];
        }
        else {
            # ok
        }
    }

    return $data;
}

1;
