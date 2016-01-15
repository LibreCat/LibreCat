package App::Validator::Department;

use Catmandu::Sane; 
use Moo;
use namespace::clean;
 
with 'Catmandu::Validator';

sub validate_data {
    my ($self,$data) = @_;

    my @errors = ();

    push @errors , 'id error' 
                unless defined($data->{_id}) && $data->{_id} =~ /^\d+/;
    
    ##
    # TODO add validator code
    ##
           
    return @errors ? \@errors : undef;
}

1;