package Authentication::LDAP;

use Net::LDAP qw(LDAP_SUCCESS);
use Net::LDAPS;

use base 'Authentication';

sub onEnter {
    my $self = shift;
    my $ldap;
    
    if ($self->param->{secure}) {
        $self->debug("ldap: connecting securely to ". $self->param->{host});
        $ldap = Net::LDAPS->new($self->param->{host}, %{$self->param->{args_to_new}});
    } else {
        $self->debug("ldap: connecting to ". $self->param->{host});
        $ldap = Net::LDAP->new($self->param->{host}, %{$self->param->{args_to_new}});
    }
    
    if (!$ldap) {
        $self->error("ldap: connect to" . $self->param->{host} . " failed");
        return;
    }
    
    if ($self->param->{base}) {
        $self->debug("ldap: binding to " . $self->param->{base});
        my $bind = $ldap->bind($self->param->{base}, password => $self->param->{password});
        
        if ($bind->code != Net::LDAP::LDAP_SUCCESS) {
            $self->error("ldap: bind to " . $self->param->{base} .  " failed");
            return;
        }
    }
    
    $self->{ldap} = $ldap;
    return 1;
}

sub onLeave {
    my $self = shift;
    if ($self->{ldap}) {
        $self->debug("ldap: unbinding");
        $self->{ldap}->unbind;
    }
}

sub verify {
    my ($self, $username, $password) = @_;
    
    my $base;
    if ($self->param->{auth_attr}) {
        my $entry = $self->lookup($username);

        
        #$self->debug("ldap: verify-lookup " . $entry);
        
        if (!$entry) {
            return;
        }
        
        $base = sprintf($self->param->{auth_base}, $entry->{$self->param->{auth_attr}});
    } else {
        $base = sprintf($self->param->{auth_base}, $username);
    }
    
    my $bind = $self->{ldap}->bind($base, password => $password);
    
    if ($bind->code == Net::LDAP::LDAP_SUCCESS) {
        return 1;
    }
    
    #$bind->{resultCode} = $username;
    return;
}

sub lookup {
    my ($self, $username, $password) = @_;
    
    my %args = ();
    $args{filter} = sprintf($self->param->{search_filter}, $username);
    $args{base}   = $self->param->{search_base};
    $args{scope}  = $self->param->{search_scope} if $self->param->{search_scope};
    $args{attrs}  = $self->param->{search_attrs} if $self->param->{search_attrs};


    if ($password){    # binding if necessary

       my $base = sprintf($self->param->{auth_base}, $username);
       $self->debug("ldap: binding in lookup to " . $base);
       my $bind = $self->{ldap}->bind($base, password => $password);
    }
    
    $self->debug("ldap: searching on base '$args{base}' for '$args{filter}' with scope '$args{scope}'");
    my $query = $self->{ldap}->search(%args);
    
    if ($query->code != Net::LDAP::LDAP_SUCCESS or $query->count != 1) {
        $self->debug("ldap: no entry found");
        return;
    }
    
    $self->debug("ldap: entry found" . $query->entry(0));
    $self->onFound($query->entry(0));
}

1;
