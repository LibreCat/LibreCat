#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /home/bup/perl5/lib/perl5);
use Catmandu -all;
use Catmandu::Sane;
use Catmandu::Fix;
use Catmandu::Util qw(as_utf8);
use Catmandu::Importer::JSON;
use Orms;
use luurCfg;
use LWP::Simple;
use HTML::Entities;
use Getopt::Std;
use Data::Dumper;

my $cfg = luurCfg->new;
my $luur = Orms->new($cfg->{ormsCfg});
my $default_style = $cfg->{citation_db}->{default_style};

Catmandu->load(":up");
my $conf = Catmandu->config;
my $adminbag = Catmandu->store('authority')->bag('admin');
my $userbag = Catmandu->store('authority')->bag('user');
my $deptbag = Catmandu->store('authority')->bag('department');
my $host = $conf->{host};

getopts('adp:');
our ($opt_a, $opt_d, $opt_p);

# main #
if($opt_p) {
	&add_person($opt_p);
	&add_sfb882profile;
} elsif ($opt_d) {
	&add_department;
} elsif ($opt_a) {
	&add_person;
	&add_department;
	&add_sfb882profile;
}

sub getPersonData {

	my $fixer = Catmandu::Fix->new(fixes => [
#		'repair_name_array("hasUserAccessThrough")',
		'repair_name_array("hasDepartmentRights")',
		'repair_name_array("hasDependent")',
		'repair_name_array("isAffiliatedWith")',
		'remove_field("oId")',
		'remove_field("oIdAccount")',
		'move_field("isSuperAdminAccount", "super_admin")',
		'remove_field("hasUserAccessThrough")',
		'move_field("luLdapId","login")',
		'move_field("jobTitle","title")',
		'move_field("fullName","full_name")',
		'move_field("surname","last_name")',
		'move_field("givenName","first_name")',
		'move_field("old_fullName", "old_full_name")',
		'move_field("old_surname", "old_last_name")',
		'move_field("old_givenName", "old_first_name")',
        'move_field("accountStatus","account_status")',
		'remove_field("isOfType")',
        'remove_field("reviewer.*.reviewer")',
        'remove_field("reviewer.*.reviewDiss")',
        'remove_field("searchName")',
		]);

	my $sbcatPerson = shift;

	my $mongo_data = ();
	my $user_data = ();
	my $citationStyle;
	my $sortDirection;

	my $sbcatAccount = $luur->getRelatedObjects(relation => "isOwnedBy", object2 => $sbcatPerson);

	my $externalRelations = $luur->getExternalRelationsInfo($sbcatPerson) if $sbcatPerson;
	my $internalRelations = $luur->getInternalRelationsInfo($sbcatPerson) if $sbcatPerson;
	my $extRelAccount = $luur->getExternalRelationsInfo(@{$sbcatAccount}[0]) if @{$sbcatAccount}[0];
	my $intRelAccount = $luur->getInternalRelationsInfo(@{$sbcatAccount}[0]) if @{$sbcatAccount}[0];

	#print Dumper $externalRelations;
	#print Dumper $internalRelations;
	#print Dumper $extRelAccount;
	#print Dumper $intRelAccount;
	#exit;

	my $record;
	$record->{oId} = $sbcatPerson;
	$record->{oIdAccount} = @{$sbcatAccount}[0];

	foreach(@{$externalRelations}){
		#$record->{oId} = $_->{erOId};
		my $rel = $luur->getObjectInfo($_->{erRelationOId});
		if($rel->{oInternalName} eq "sortDirection"){
			$sortDirection = $_->{erValue};
		}
		elsif($rel->{oInternalName} eq "citationStyle"){
			$citationStyle = $_->{erValue};
		}
		elsif($rel->{oInternalName} eq "fullName" or $rel->{oInternalName} eq "surname" or $rel->{oInternalName} eq "givenName"){
			if(!$_->{erEndDate}){
				$record->{$rel->{oInternalName}} = $_->{erValue};
			}
			elsif(!$_->{erStartDate} and $_->{erEndDate}){
				$record->{"old_" . $rel->{oInternalName}} = $_->{erValue};
			}
		}
		else {
			$record->{$rel->{oInternalName}} = $_->{erValue};
		}
	}

	foreach(@{$internalRelations}){
		my $rel = $luur->getObjectInfo($_->{irRelationOId});
		if($rel->{oInternalName} eq "isOfType"){
			my $relation = $luur->getObjectInfo($_->{irOId2});
			$record->{$rel->{oInternalName}} = $relation->{oInternalName};
		}
		if($rel->{oInternalName} eq 'isAffiliatedWith'){
			my $relation = $luur->getAttributeValues(object => $_->{irOId2});
			push @{$record->{department}}, {id => $relation->{organizationNumber}, name => (ref $relation->{name} eq "ARRAY" ? $relation->{name}->[0] : $relation->{name})};
		}
		unless ($rel->{oInternalName} eq "isOwnedBy" or $rel->{oInternalName} eq "isAuthoredBy" or $rel->{oInternalName} eq "isEditedBy" or $rel->{oInternalName} eq "isHiddenFor" or $rel->{oInternalName} eq "isOfType" or $rel->{oInternalName} eq 'isAffiliatedWith'){
			if($_->{irOId1} eq $record->{oId}){
				my $related = $luur->getAttributeValues(object => $_->{irOId2});
				$record->{$rel->{oInternalName}} = () unless $record->{$rel->{oInternalName}};
				push @{$record->{$rel->{oInternalName}}}, $related;
			}
			elsif($_->{irOId2} eq $record->{oId}){
				my $related = $luur->getAttributeValues(object => $_->{irOId1});
				$record->{$rel->{oInternalName}} = () unless $record->{$rel->{oInternalName}};
				push @{$record->{$rel->{oInternalName}}}, $related;
			}
		}
	}

	foreach(@{$extRelAccount}){
		#$record->{oId} = $_->{erOId};
		my $rel = $luur->getObjectInfo($_->{erRelationOId});
		$record->{$rel->{oInternalName}} = $_->{erValue};
	}

	foreach(@{$intRelAccount}){
		my $rel = $luur->getObjectInfo($_->{irRelationOId});
		if($rel->{oInternalName} eq "hasDepartmentRights"){ #or $rel->{oInternalName} eq "hasDependent"){
			if($_->{irOId1} eq $record->{oIdAccount}){
				my $relatedAttribs = $luur->getAttributeValues(object => $_->{irOId2});
				my $relatedRelation = $luur->getRelatedObjects(object1 => $_->{irOId2}, relation => "isForDepartment");
				my $dept = $luur->getAttributeValues(object => @$relatedRelation[0]);
				my $relatedAttr;
				$relatedAttr->{reviewer} = $relatedAttribs->{reviewOtherRight} ? "1" : "0";
				$relatedAttr->{reviewDiss} = $relatedAttribs->{reviewDissertationRight} ? "1" : "0";
				$relatedAttr->{department}->{id} = $dept->{organizationNumber};
				$relatedAttr->{department}->{name} = ref $dept->{name} eq "ARRAY" ? @{$dept->{name}}[0] : $dept->{name};
				push @{$record->{reviewer}}, $relatedAttr;
			}
		}
		unless ($rel->{oInternalName} eq "isOwnedBy" or $rel->{oInternalName} eq "isAuthoredBy" or $rel->{oInternalName} eq "isEditedBy" or $rel->{oInternalName} eq "isHiddenFor" or $rel->{oInternalName} eq "isOfType" or $rel->{oInternalName} eq "isCreatedFromAccount" or $rel->{oInternalName} eq "isUploadedBy" or $rel->{oInternalName} eq "isHiddenForAccount" or $rel->{oInternalName} eq "hasDepartmentRights" or $rel->{oInternalName} eq "hasDependent"){
			if($_->{irOId1} eq $record->{oIdAccount}){
				my $related = $luur->getAttributeValues(object => $_->{irOId2});
				$record->{$rel->{oInternalName}} = () unless $record->{$rel->{oInternalName}};
				push @{$record->{$rel->{oInternalName}}}, $related;
			}
			elsif($_->{irOId2} eq $record->{oIdAccount}){
				my $related = $luur->getAttributeValues(object => $_->{irOId1});
				$record->{$rel->{oInternalName}} = () unless $record->{$rel->{oInternalName}};
				push @{$record->{$rel->{oInternalName}}}, $related;
			}
		}
	}

	$record->{_id} = $record->{personNumber};

	if($record->{_id}){
		$mongo_data = $adminbag->get($record->{_id});
		foreach my $key (keys %$record){
			$mongo_data->{$key} = $record->{$key};
		}
	}
	$fixer->fix($mongo_data) if $mongo_data;
	$adminbag->add($mongo_data) if $mongo_data;


	my $id = "";
	if($record->{_id}){
		$user_data = $userbag->get($record->{_id});
		$id = $record->{_id};
	}

	if($mongo_data){
		$user_data->{citationStyle} = $citationStyle;
		$user_data->{sortDirection} = $sortDirection;
		# BIS API
		my $base = 'http://ekvv.uni-bielefeld.de/ws/pevz/PersonKerndaten.xml?';
		my $base2 = 'http://ekvv.uni-bielefeld.de/ws/pevz/PersonKontaktdaten.xml?';
		my $url = $base . "persId=$id";
		my $url2 = $base2 . "persId=$id";
		my $res = "";
		$res = get($url) or $res = "";
		my $res2 = "";
		$res2 = get($url2) or $res2 = "";
		my ($photo) = $res =~ /bildskalierturl>(.*?)<\/pevz:bildskalierturl/g;
		my ($personTitle) = $res =~ /titel>(.*?)<\/pevz:titel/g;
		my ($personName) = $res =~ /nachname>(.*?)<\/pevz:nachname/g;
		my $email = '';
		($email) = $res2 =~ /email_verschleiert>(.*?)<\/pevz:email_verschleiert/g;
		decode_entities ($email) if $email;
		my $former = ($res2 =~ /<\/pevz:kontakte>/) ? "0" : "1";
		my $nonexist = ($former and !$personName) ? "1" : "0";
		my $forschend = ($res =~ /forschend="forschend"/) ? "1" : "0";

		$user_data->{_id} = $id;
		$user_data->{bis}->{photo} = $photo;
		$user_data->{bis}->{email} = $email;
		$user_data->{bis}->{forschend} = $forschend;
		$user_data->{bis}->{former} = $former;
		$user_data->{bis}->{nonExist} = $nonexist;
		#$user_data->{bis}->{personTitle} = $personTitle;

		$fixer->fix($user_data);

		$userbag->add($user_data);
	}

}

sub add_department {

	my $dep_url = "http://pub.uni-bielefeld.de/luur/authority_organization?func=getOrganizations";

	use LWP::Simple;
	use XML::Simple;
	my $html = get($dep_url);
	my $xml = XMLin($html, ForceArray => ['name']);

	my $orgunit = $xml->{organizationalUnit};

	foreach(@$orgunit){
		my $dep_hash;

		$dep_hash->{_id} = $_->{organizationNumber};
		$dep_hash->{oId} = $_->{organizationNumber};
		$dep_hash->{name} = $_->{name}->[0]->{content}; #forcearray on "name" makes this possible
		$dep_hash->{name_lc} = lc $_->{name}->[0]->{content};

		push @{$dep_hash->{tree}}, {id => $_->{organizationNumber}, name => $_->{name}->[0]->{content}};
		my $parent = $_->{parent};
		if($parent and $parent ne "0"){
			my @matching_items = grep {$_->{organizationNumber} eq $parent} @$orgunit;
			$parent = $matching_items[0];
			push @{$dep_hash->{tree}}, {id => $parent->{organizationNumber}, name => $parent->{name}->[0]->{content}};

			if($parent->{parent} and $parent->{parent} ne "0"){
				@matching_items = grep {$_->{organizationNumber} eq $parent->{parent}} @$orgunit;
				my $parentparent = $matching_items[0];
				push @{$dep_hash->{tree}}, {id => $parentparent->{organizationNumber}, name => $parentparent->{name}->[0]->{content}};
			}
		}

		my ($sec,$min,$hour,$day,$mon,$year) = localtime(time);
		$dep_hash->{dateLastChanged} = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", 1900+$year, 1+$mon, $day, $hour, $min, $sec);

		$deptbag->add($dep_hash);
	}
}

sub add_person {

	my $id = shift;

	if($id) {
		my $person = $luur->getObjectsByAttributeValues(type => 'luAuthor', attributeValues => { personNumber => $id});
		my $p = @{$person}[0];
		if($p and $p ne "" and $p =~ /\d{1,}/){
			&getPersonData($p);
		}
		else{
			print "Invalid ID!\n";
		}
	} else {
		my $person = $luur->getObjectsByType(type => 'luAuthor');

		foreach my $p (@$person) {
			if ($p and $p ne "" and $p =~ /\d{1,}/){
				&getPersonData($p);
			}
			else {
				print "Invalid ID!\n"
			}
		}
	}

}

sub add_sfb882profile {
	use LWP::Simple;
	use JSON;
	my $bisids = get("http://www.sfb882.uni-bielefeld.de/sites/default/pubsync/get_published_profiles.php");
	my $bisjson = from_json($bisids);
	foreach(@$bisjson){
		my $record = $userbag->get($_->[0]);
		if($record and $record ne ""){
			$record->{"sfb882_profile"} = "1";
			$userbag->add($record);
			$record = "";
		}
	}
}

=head1 SYNOPSIS

Script for indexing authority data

=head2 Create/refresh authority store

bin/add_authority.pl

bin/add_authority.pl -r

=head2 Update store with a person's infos

bin/add_authority.pl -p [person's BIS ID]

=head1 VERSION

0.02, Feb. 2013, vitali

=cut
