package Catmandu::Fix::clean_department;

use Catmandu::Sane;
use Moo;

sub fix {
	my ( $self, $pub ) = @_;
	my $dep = $pub->{department};
	
	foreach (@$dep) {
		delete $_->{oId} if $_->{oId};
		delete $_->{type} if $_->{type};
		
		#ref $pub->{author} eq 'ARRAY' ? $pub->{author}->[0]->{fullName} : $pub->{author}->{fullName};
		if (ref $_->{name} eq 'ARRAY') {
			$_->{name} = $_->{name}->[0]->{text};
		}
		
		$_->{id} = $_->{organizationNumber};
		delete $_->{organizationNumber};
		$_->{tree} = $_->{allDepartments};
		delete $_->{allDepartments};
	}
	
	$pub;
}

1;