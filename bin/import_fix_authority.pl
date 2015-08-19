#!/usr/bin/env perl
use Catmandu::Sane;
use Catmandu -all;
use Data::Dumper;
use Catmandu::Fix qw(datetime_format move_field remove_field);
use Catmandu::Store::MongoDB;

Catmandu->load(':up');
my $conf = Catmandu->config;

my $deptBag = Catmandu->store('backup')->bag('department');
my $mongoBag = Catmandu->store('backup')->bag('researcher');

use Catmandu::Importer::JSON;

my $importer_new = Catmandu::Importer::JSON->new(file => "authority_new.json");
my $importer = Catmandu::Importer::JSON->new(file => "authority_mongo.json");

my $m = $importer_new->each(sub {
	my $record = $_[0];
	if($record->{type} and $record->{type} eq "person"){
		$record->{title} = $record->{personTitle} if $record->{personTitle};
		$record->{bis}->{former} = $record->{bis_former} ? 1 : 0;
		$record->{bis}->{photo} = $record->{bis_photo} if $record->{bis_photo};
		$record->{bis}->{forschend} = $record->{bis_forschend} ? 1 : 0;
		$record->{bis}->{email} = $record->{bis_email} if $record->{bis_email};
		$record->{bis}->{nonexist} = $record->{bis_nonExist} ? 1 : 0;
		$record->{bis}->{title} = $record->{bis_personTitle} if $record->{bis_personTitle};
		delete $record->{bis_former} if $record->{bis_former};
		delete $record->{bis_photo} if $record->{bis_photo};
		delete $record->{bis_forschend} if $record->{bis_forschend};
		delete $record->{bis_email} if $record->{bis_email};
		delete $record->{bis_nonExist} if $record->{bis_nonExist};
		delete $record->{bis_personTitle} if $record->{bis_personTitle};
		delete $record->{access} if $record->{access};
		$record->{style} = "default" if ($record->{style} && $record->{style} eq "frontShort");
		$mongoBag->add($record);
	}
	elsif($record->{type} and $record->{type} eq "organization") {
        delete $record->{type};
		my $sbcat_rec;
		$sbcat_rec->{_id} = $record->{_id};
		$sbcat_rec->{name} = $record->{name};
		$sbcat_rec->{layer} = $record->{layer};
		$sbcat_rec->{tree} = $record->{tree};
		$sbcat_rec->{display} = join(' > ', map { $_->{name}; } @{$record->{tree}});
        $deptBag->add($sbcat_rec);
    }
});

my $n = $importer->each(sub {
	my $hashref = $_[0];
	my $sbcat_rec = $mongoBag->get($hashref->{_id});
	next if !$sbcat_rec;

	my $pre_fixer = Catmandu::Fix->new(
    fixes => [
        'remove_field("dateLastChanged")',
        'remove_field("jobTitle")',
        'move_field("githubId","github")',
        'move_field("googleScholarId","googleScholar")',
        'move_field("orcidId","orcid")',
        'move_field("arxivId","arxiv")',
        'move_field("inspireId","inspire")',
        'remove_field("fullName")',
        'remove_field("surname")',
        'remove_field("searchName")',
        'remove_field("sbcatId")',
        'remove_field("affiliation")',
        'remove_field("givenName")',
        'remove_field("email")',
        'remove_field("stylePreference")',
        'remove_field("personTitle")',
		'remove_field("bis_forschend")',
		'remove_field("bis_former")',
		'remove_field("bis_photo")',
		'remove_field("bis_email")',
		'remove_field("bis_nonExist")',
		'remove_field("bis_personTitle")',
		'remove_field("access")',
		#'add_num_of_publs()',
        ]
    );

    $pre_fixer->fix($hashref);

    #$hashref->{date_updated} =~ s/(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})/$1T$2/g if $hashref->{date_updated};

#    if($hashref->{stylePreference} and $hashref->{stylePreference} =~ /(.*?)\.(.*?)/){
#    	$hashref->{style} = $1;
#    	delete $hashref->{stylePreference};
#    }

    #print Dumper $hashref;
  #  if($hashref->{type} eq "person"){
    	#foreach my $dept (@{$hashref->{department}}){
    	#	delete $dept->{departmentOId};
    	#	$dept->{id} = $dept->{organizationNumber};
    	#	delete $dept->{organizationNumber};
    	#}
    	#$hashref->{bis}->{former} = $hashref->{bis_former} ? 1 : 0;
    	#$hashref->{bis}->{photo} = $hashref->{bis_photo} ? $hashref->{bis_photo} : "";
    	#$hashref->{bis}->{forschend} = $hashref->{bis_forschend} ? 1 : 0;
    	#$hashref->{bis}->{email} = $hashref->{bis_email} if $hashref->{bis_email};
    	#$hashref->{bis}->{nonexist} = $hashref->{bis_nonExist} ? 1 : 0;
    	#$hashref->{bis}->{title} = $hashref->{bis_personTitle} if $hashref->{bis_personTitle};
    	delete $hashref->{bis_former};
    	delete $hashref->{bis_photo};
    	delete $hashref->{bis_forschend};
    	delete $hashref->{bis_email};
    	delete $hashref->{bis_nonExist};
    	delete $hashref->{bis_personTitle};
    	delete $hashref->{type};
    	#print Dumper $hashref;

    	#print Dumper $sbcat_rec;
    	foreach my $key (keys %$hashref){
			$sbcat_rec->{$key} = $hashref->{$key};
		}
    	$mongoBag->add($sbcat_rec);
    	#$authBag->add($sbcat_rec);
    	#print Dumper $sbcat_rec;
   # }
   # elsif($hashref->{type} eq "organization") {
    #	delete $hashref->{type};
    	#my $sbcat_rec = $mongoBag->get($hashref->{_id});
    	#my $dept_rec;
    	#print Dumper $sbcat_rec;
    	#foreach my $key (keys %$hashref){
	#		$sbcat_rec->{$key} = $hashref->{$key};
	#	}
    #	$deptBag->add($sbcat_rec);
   # }

});


1;
