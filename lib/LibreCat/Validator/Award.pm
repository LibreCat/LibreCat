package LibreCat::Validator::Award;

use Catmandu::Sane;
use Moo;
use namespace::clean;

with 'Catmandu::Validator';

sub validate_data {
    my ($self,$data) = @_;

    my @errors = ();

    push @errors , 'id error'
                unless defined($data->{_id}) && $data->{_id} =~ /^AW\d+/;

    ##
    # TODO add validator code
    ##

    return @errors ? \@errors : undef;
}

1;
