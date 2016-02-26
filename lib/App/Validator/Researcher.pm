package App::Validator::Researcher;

use Catmandu::Sane; 
use Moo;
use namespace::clean;
 
with 'Catmandu::Validator';

sub validate_data {
    my ($self,$data) = @_;

    my @errors = ();

    push @errors , 'id error' 
                unless defined($data->{_id}) && $data->{_id} =~ /^\d+/;
    push @errors , 'account_status error'
                unless defined($data->{account_status}) && $data->{account_status} =~ /^(in)?active$/;
    push @errors , 'account_type error'
                unless defined($data->{account_type}) && $data->{account_type} =~ /^\S+$/;
    push @errors , 'password error'
                unless defined($data->{password}) && $data->{password} =~ /^\S+$/;
    push @errors , 'login error'
                unless defined($data->{login}) && $data->{login} =~ /^\S+$/;
    push @errors , 'department error'
                unless defined($data->{department});
    push @errors , 'email error'
                unless defined($data->{email}) && $data->{email} =~ /^\S+$/;
    push @errors , 'first_name error'
                unless defined($data->{first_name}); 
    push @errors , 'last_name error'
                unless defined($data->{last_name});
    push @errors , 'full_name error'
                unless defined($data->{full_name});
                                  
    return @errors ? \@errors : undef;
}

1;