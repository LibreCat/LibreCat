#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -all;
use Data::Dumper;

Catmandu->load(':up');
my $conf = Catmandu->config;

my $mongoBag = Catmandu->store('award');
my $awardBag = Catmandu->store('award')->bag('award');
#my $preisBag = Catmandu->store('search', index_name => $index_name)->bag('award');

use Catmandu::Importer::JSON;

my $importer = Catmandu::Importer::JSON->new(file => "award_awards.json");

my $n = $importer->each(sub {
	my $hashref = $_[0];
	my $pre_fixer = Catmandu::Fix->new(
    fixes => [
        'move_field("dateLastChanged","date_updated")',
        ]
    );
    $pre_fixer->fix($hashref);
    #print Dumper $hashref;
    $awardBag->add($hashref);
});

my $importer2 = Catmandu::Importer::JSON->new(file => "award_academy.json");

my $n2 = $importer2->each(sub {
	my $hashref = $_[0];
	$hashref->{oldid} = $hashref->{_id};
	my $ids = $awardBag->pluck("_id")->to_array;
	my @newIds;
    foreach (@$ids){
        $_ =~ s/^AW//g;
        push @newIds, $_;
    }
    @newIds = sort {$a <=> $b} @newIds;
    my $idsLength = @newIds;
    my $createdid = $newIds[$idsLength-1];
    $createdid++;
    
    $hashref->{_id} = "AW" . $createdid;
    my $pre_fixer = Catmandu::Fix->new(
    fixes => [
        'move_field("dateLastChanged","date_updated")',
        'add_field("type","akademie")',
        ]
    );
    $pre_fixer->fix($hashref);
    $awardBag->add($hashref);
    #print Dumper $hashref;
});


my $importer3 = Catmandu::Importer::JSON->new(file => "award_preise.json");

my $n3 = $importer3->each(sub {
	my $hashref = $_[0];
	
	if($hashref->{academyId}){
		my $correct_id = $awardBag->select("oldid", $hashref->{academyId})->to_array;
		$hashref->{award_id} = $correct_id->[0]->{_id};
		delete $hashref->{academyId};
	}
	if($hashref->{awardId}){
		$hashref->{award_id} = $hashref->{awardId};
		delete $hashref->{awardId};
	}
	
    my $pre_fixer = Catmandu::Fix->new(
    fixes => [
        'move_field("dateLastChanged","date_updated")',
        'move_field("uniBiMember", "uni_member")',
        'move_field("formerMember", "former_member")',
        'move_field("otherUniv", "other_university")',
        'move_field("awardedWhileNotUnibi", "extern")',
        
        ]
    );
	
	my $honoree;
	$honoree->{first_name} = $hashref->{honoree}->{name}->{givenName};
	$honoree->{last_name} = $hashref->{honoree}->{name}->{surname};
	$honoree->{full_name} = $hashref->{honoree}->{name}->{fullName};
	$honoree->{title} = $hashref->{honoree}->{name}->{personTitle} if $hashref->{honoree}->{name}->{personTitle};
	$honoree->{id} = $hashref->{honoree}->{name}->{personNumber} if $hashref->{honoree}->{name}->{personNumber};
	delete $hashref->{honoree};
	push @{$hashref->{honoree}}, $honoree;
	
	foreach my $dep (@{$hashref->{department}}){
		$dep->{id} = $dep->{organizationNumber};
		delete $dep->{organizationNumber};
		delete $dep->{sbcatId};
	}
	
	if($hashref->{einrichtung}){
		foreach my $dep (@{$hashref->{einrichtung}}){
			$dep->{id} = $dep->{organizationNumber};
			delete $dep->{organizationNumber};
			delete $dep->{sbcatId};
		}
	}
	
	delete $hashref->{description} if (!$hashref->{description});
	delete $hashref->{description_en} if (!$hashref->{description_en});
	
	$hashref->{uniBiMember} = $hashref->{uniBiMember} eq "ja" ? 1 : 0;
	$hashref->{awardedWhileNotUnibi} = $hashref->{awardedWhileNotUnibi} ne "nein" ? 1 : 0;
    
    $pre_fixer->fix($hashref);
    $mongoBag->add($hashref);
    #print Dumper $hashref;
    #print "\n";
});

1;