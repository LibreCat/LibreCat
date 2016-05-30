package Catmandu::Fix::delete_empty;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $data) = @_;

    foreach my $key (keys %$data) {
        my $ref = ref $data->{$key};

        if ($ref eq "ARRAY") {
            if (!$data->{$key}->[0]) {
                delete $data->{$key};
            }
        }
        elsif ($ref eq "HASH") {
            if (!%{$data->{$key}}) {
                delete $data->{$key};
            }
        }
        else {
            if ($data->{$key} and $data->{$key} eq "") {
                delete $data->{$key};
            }
            elsif (defined $data->{$key} and $data->{$key} eq "0") {
                delete $data->{$key};
            }
        }
    }

    return $data;
}

1;
