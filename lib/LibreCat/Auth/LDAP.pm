package LibreCat::Auth::LDAP;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Net::LDAP;
use Moo;
use Carp;
use namespace::clean;

with 'LibreCat::Auth';

has host          => (is => 'ro', required => 1);
has base          => (is => 'ro');
has password      => (is => 'ro');
has auth_base     => (is => 'ro', required => 1);
has search_filter => (is => 'ro');
has search_base   => (is => 'ro');
has search_attr   => (is => 'ro');
has ldap          => (is => 'lazy');

# TODO use exceptions for connection errors
sub _build_ldap {
    my ($self) = @_;

    $self->log->debug("connecting to " . $self->host);
    my $ldap = Net::LDAP->new($self->host);

    unless ($ldap) {
        $self->log->error("...connection failed");
        return undef;
    }

    if ($self->base) {
        $self->log->debug("binding to " . $self->base);
        my $bind = $ldap->bind($self->base, password => $self->password);

        $self->log->debug("...code " . $bind->code);

        return undef unless $bind->code == Net::LDAP::LDAP_SUCCESS;
    }

    $ldap;
}

# TODO use exceptions for programming errors
sub _authenticate {
    my ($self, $params) = @_;

    return undef unless is_hash_ref($params);

    my $username = $params->{username};
    my $password = $params->{password} // "";

    return undef unless defined $username;
    return undef unless defined $self->ldap;

    # Check if we need to translate the username
    if ($self->search_filter && (my $res = $self->search($username))) {
        $username = $res;
    }

    $self->log->debug(
        "username: $username ; password: " . length($password) . " bytes");

    my $base = sprintf($self->auth_base, $username);

    $self->log->debug("binding to $base");
    my $bind = $self->ldap->bind($base, password => $password);

    $self->log->error("...bind failed") unless $bind;

    return undef unless $bind;

    $self->log->debug("...code " . $bind->code . ": error: " . $bind->error);

    $self->log->debug("unbind");
    $self->ldap->unbind;

    $bind->code == Net::LDAP::LDAP_SUCCESS
        ? +{uid => $username, package => __PACKAGE__, package_id => $self->id}
        : undef;
}

# TODO use exception objects
sub search {
    my ($self, $username) = @_;

    croak "need search_filter" unless $self->search_filter;
    croak "need search_base"   unless $self->search_base;
    croak "need search_attr"   unless $self->search_attr;

    return undef unless is_string($username);
    $self->log->debug("searching $username");

    my %args;
    $args{filter} = sprintf($self->search_filter, $username);
    $args{base}   = $self->search_base;
    $args{attrs}  = [$self->search_attr];

    $self->log->debugf("%s", \%args);

    my $query = $self->ldap->search(%args);

    $self->log->debug("...code " . $query->code);
    $self->log->debug("...count " . $query->count);

    if ($query->code != Net::LDAP::LDAP_SUCCESS or $query->count != 1) {
        return undef;
    }

    $query->entry(0)->get_value($self->search_attr);
}

1;

__END__

=pod

=head1 NAME

LibreCat::Auth::LDAP - A LibreCat LDAP authentication package

=head1 SYNOPSIS

    use LibreCat::Auth::LDAP;

    my $auth = LibreCat::Auth::LDAP->new(
        host => 'ldaps://ldaps.ugent.be'
        auth_base => 'ugentID=%s,ou=people,dc=UGent,dc=be'
    );

    if ($auth->authenticate({username => $username,
            password => $password})) {
        say "logged in";
    }
    else {
        say "error";
    }

=head1 CONFIG

=head2 host

The URL to the LDAP server. Use ldaps:// for a secure connection. Required

=head2 auth_base

The base to use when authenticating user credentials. Required

=head2 base

When a double binding is required, the the bind parameters before checking user credentials.

=head2 password

An optional password required when doing a double binding.

=head2 search_filter

Some LDAP servers may require you to lookup a user identifier. Set a search filter
to lookup a user. E.g.

     search_filter => '(uid=%s)'

=head2 search_base

The base to search with a search_filter. E.g.

     search_base => 'dc=ugent, dc=be'

=head2 search_attr

The attribute to return from a search filter. E.g.

     search_attr: 'ugentID'

In the examples above a user name like 'einstein' will be searched as (uid=einstein) in the
base 'dc=ugent, dc=be'. When a search result is found, then the login name will be translated
to the 'ugentID' of the user.

=head1 SEE ALSO

L<LibreCat::Auth>

=cut
