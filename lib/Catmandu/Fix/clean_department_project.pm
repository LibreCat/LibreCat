package Catmandu::Fix::clean_department_project;

use Catmandu::Sane;
use Moo;

sub fix {
	my ( $self, $pub ) = @_;
	
	if($pub->{department}){
		foreach my $dep (@{$pub->{department}}) {
			my $dept;
			
			if (ref $dep->{name} eq 'ARRAY') {
				$dept = $dep->{name}->[0]->{text};
				delete $dep->{name};
				$dep->{name} = $dept;
			}
			
			delete $dep->{oId} if $dep->{oId};
			delete $dep->{type} if $dep->{type};
			
			$dep->{id} = $dep->{organizationNumber} if $dep->{organizationNumber};
			delete $dep->{organizationNumber};
			
			@{$dep->{tree}} = @{$dep->{allDepartments}} if $dep->{allDepartments};
			delete $dep->{allDepartments};
		}
	}
	
	if($pub->{project}){
		foreach my $pro (@{$pub->{project}}) {
			my $proj;
			
			if (ref $pro->{name} eq 'ARRAY') {
				$proj = $pro->{name}->[0]->{text};
				delete $pro->{name};
				$pro->{name} = $proj;
			}
			
			$pro->{id} = $pro->{projectId} if $pro->{projectId};
			delete $pro->{projectId};
			
			delete $pro->{oId} if $pro->{oId};
			delete $pro->{type} if $pro->{type};
			delete $pro->{startYear} if $pro->{startYear};
			delete $pro->{endYear} if $pro->{endYear};
			delete $pro->{sc39} if $pro->{sc39};
			delete $pro->{grantNumber} if $pro->{grantNumber};
			delete $pro->{callIdentifier} if $pro->{callIdentifier};
			delete $pro->{pspElement} if $pro->{pspElement};
		}
	}
	
	$pub;
}

1;