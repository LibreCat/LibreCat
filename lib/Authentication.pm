=head1 NAME

Authentication - A LibreCat authentication package

=head1 SYNOPSIS

	package MyAuthentication;

	use Moo;

	with 'Authentication';

	sub authenticate {
    	my ($self,$username,$password) = @_;

    	return $password eq 'secret' ? 1 : 0;
    }

	1;

=head1 DESCRIPTION

This is a Moo::Role for all authentication packages. Required is a method that 
implements the C<authenticate> method.

=head1 SEE ALSO

L<Authentication::LDAP>

=cut
package Authentication;

use namespace::clean;
use Catmandu::Sane;
use Moo::Role;

with 'Catmandu::Logger';

# All authentication packages need to implement one method
# authenticate($username,$password)
# Returns: 1 on success, 0 on failure , -1 on error
requires 'authenticate';

1;
