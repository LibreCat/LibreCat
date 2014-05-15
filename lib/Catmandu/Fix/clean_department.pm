package Catmandu::Fix::clean_department;

use Catmandu::Sane;
use Moo;

sub fix {
	my ( $self, $pub ) = @_;
	my $department = $pub->{department};
	
	foreach my $dep (@$department) {
		delete $dep->{oId} if $dep->{oId};
		delete $dep->{type} if $dep->{type};
		
		if (ref $dep->{name} eq 'ARRAY') {
			$dep->{name} = $dep->{name}->[0]->{text};
		}
		
		$dep->{id} = $dep->{organizationNumber};
		delete $dep->{organizationNumber};
		$dep->{tree} = $dep->{allDepartments};
		delete $dep->{allDepartments};
	}
	
	$pub;
}

1;