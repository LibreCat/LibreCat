package Catmandu::Fix::form2schema;

use Catmandu::Sane;
use Moo;
use Catmandu::Fix::Has;

has field => (fix_arg => 1);

sub fix {
    my ($self, $data) = @_;
    my $field = $self->field;
    if ( my $path = $data->{$field} and @{$data->{$field}} )
    {
        my $out;
        foreach my $pid (@$path) {
            $pid->{type} = 'unknown' unless $pid->{type} && length $pid->{type};
            $out->{$pid->{type}} = [] unless $out->{$pid->{type}};
            push @{$out->{$pid->{type}}}, $pid->{value};
        }

        delete $data->{$field};
        $data->{$field} = $out if $out;
    }

    return $data;
}

1;

__END__

=pod

=head1 NAME

Catmandu::Fix::form2schema - transforms data from form into a schema-valid structure

=head1 SYNOPSIS

    # turns data like
    # [
    #     {type  => 'isbn', value => '1234567890'},
    #     {type  => 'isbn', value => '0987654321'},
    #     {type  => 'issn', value => '12345678'},
    #     {value => 'test'},
    # ]

    form2schema(field_name)

    # into data like
    # {
    #     isbn    => ['1234567890', '0987654321'],
    #     issn    => ['12345678'],
    #     unknown => ['test'],
    # }

=cut
