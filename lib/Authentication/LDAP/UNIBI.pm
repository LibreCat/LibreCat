package Authentication::LDAP::UNIBI;

use base 'Authentication::LDAP';

sub onFound {
    my $self  = shift;
    my $entry = shift;
    my $found = {};
    
    $found->{name}             = $entry->get_value('cn');
    $found->{surname}          = $entry->get_value('sn');
    $found->{givenName}        = $entry->get_value('givenName');
    $found->{email}            = $entry->get_value('mail');
    $found->{personTitle}      = $entry->get_value('title');
    $found->{affiliation}      = $entry->get_value('departmentnumber') || 'UNIBI' ;
    $found->{personNumber}     = $entry->get_value('unibiBisID') ;
    $found->{isStudentAccount} = "" ;
    $found->{address}          = "";
    
    $found;
}

1;
