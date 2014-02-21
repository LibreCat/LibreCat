#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /home/bup/perl5/lib/perl5);
use strict;
use warnings;

use Getopt::Std;
use SBCatDB;
use Catmandu -all;

my $sb_home = '/srv/www/app-catalog';
my $perl_version = '/home/bup/perl5/perlbrew/perls/perl-5.16.3/bin/perl';

#my $log = "$sb_home/log/update_es_time.log";
my ($sec,$min,$hour,$day,$mon,$year) = localtime(time);
my $last_indexed = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", 1900+$year, 1+$mon, $day, $hour, $min, $sec);
#my $last_indexed = "2014-01-09T14:00:00";#`head -1 $log`;

use luurCfg;
use Orms;
my $cfg = luurCfg->new;
my $orm = $cfg->{ormsCfg};
my $luur = Orms->new($cfg->{ormsCfg});

my $newPub = "backenddefault";

#print "[$last_indexed] Called skript 'updateIndexSwitch.pl'.\n";
print "Called script 'updateIndexSwitch.pl'.\n";

my $status = `curl -s -XGET 'http://localhost:9200/backend1/_status'`;

if($status =~ /"status":404}$/){
	print "backend1 does not exists, new index will be backend1.\n";
	$newPub = "backend1";
} else {
	$status = `curl -s -XGET 'http://localhost:9200/backend2/_status'`;

	if($status =~ /"status":404}$/){
		print "backend2 does not exist, new index will be backend2.\n";
		$newPub = "backend2";
	}
	else {
		print "Both indexes exist. Find out which one is running and delete the other.\n Then restart!\n";
		exit;
	}
}

my $command_1 = "$perl_version $sb_home/bin/index_publication.pl";
my $command_2 = "$perl_version $sb_home/bin/index_project.pl";
my $command_3 = "$perl_version $sb_home/bin/index_researcher.pl";
my $command_4 = "$perl_version $sb_home/bin/index_award.pl";

if($newPub eq "backend2"){
	$command_1 .= " -m backend2";
	$command_2 .= " -m backend2";
	$command_3 .= " -m backend2";
	$command_4 .= " -m backend2";
}
elsif($newPub eq "backend1"){
	$command_1 .= " -m backend1";
	$command_2 .= " -m backend1";
	$command_3 .= " -m backend1";
	$command_4 .= " -m backend1";
}

print "Indexing publications.\n";
my $result_1 = `$command_1`;

print "Indexing projects.\n";
my $result_2 = `$command_2`;

print "Indexing researchers.\n";
my $result_3 = `$command_3`;

print "Indexing awards.\n";
my $result_4 = `$command_4`;


if($newPub eq "backend2"){
	print "New index is backend2. Testing.\n";
	my $checkForIndex = `curl -s -XGET 'http://localhost:9200/backend2/_status'`;
	if($checkForIndex =~ /{"ok":true/){
		print "Index backend2 is ok. Setting index alias 'backend' to backend2, testing and then deleting index backend1.\n";
		
		my $switchAlias = `curl -s -XPOST 'http://localhost:9200/_aliases' -d '
		    {
			    "actions" : [
			    { "remove" : { "index" : "backend1", "alias" : "backend" } },
			    { "add" : { "index" : "backend2", "alias" : "backend" } }
			    ]
		    }'`;
		    
		$checkForIndex = "";
		$checkForIndex = `curl -s -XGET 'http://localhost:9200/backend/_status'`; # index should be there, alias should be in effect
		if($checkForIndex =~ /{"ok":true/){
			print "Alias 'backend' is ok and points to index backend2. Deleting backend1.\n";
			my $deleted = `curl -s -XDELETE 'http://localhost:9200/backend1'`;
			print "Checking if backend1 was deleted.\n";
			my $checkDeletedIndex = `curl -s -XGET 'http://localhost:9200/backend1/_status'`;
			if($deleted =~ /{"ok":true/ and $checkDeletedIndex =~ /{"error":"IndexMissingException/){
				print "Index backend1 deleted!\n";
			}
			else {
				print "Index backend1 was NOT deleted, trying again.\n";
				$deleted = `curl -s -XDELETE 'http://localhost:9200/backend1'`;
				print "ElasticSearch delete message: $deleted\n";
			}
		}
	}
	else {
		print "Creating new index failed! Old index still in effect.\n";
                `curl -s -XDELETE 'http://localhost:9200/backend2'`;
		exit;
	}
}
else {
	print "New index is backend1. Testing.\n";
	my $checkForIndex = `curl -s -XGET 'http://localhost:9200/backend1/_status'`;
	if($checkForIndex =~ /{"ok":true/){
		print "Index backend1 is ok. Setting index alias 'backend' to backend1, testing and then deleting index backend2.\n";
		
		my $switchAlias = `curl -s -XPOST 'http://localhost:9200/_aliases' -d '
		    {
			    "actions" : [
			    { "remove" : { "index" : "backend2", "alias" : "backend" } },
			    { "add" : { "index" : "backend1", "alias" : "backend" } }
			    ]
		    }'`;
		    
		$checkForIndex = "";
		$checkForIndex = `curl -s -XGET 'http://localhost:9200/backend/_status'`; # index should be there, alias should be in effect
		if($checkForIndex =~ /{"ok":true/){
			print "Alias 'backend' is ok and points to index backend1. Deleting backend2.\n";
			my $deleted = `curl -s -XDELETE 'http://localhost:9200/backend2'`;
			print "Checking if backend2 was deleted.\n";
			my $checkDeletedIndex = `curl -s -XGET 'http://localhost:9200/backend2/_status'`;
			if($deleted =~ /{"ok":true/ and $checkDeletedIndex =~ /{"error":"IndexMissingException/){
				print "Index backend2 deleted!\n";
			}
			else {
				print "Index backend2 was NOT deleted, trying again.\n";
				$deleted = `curl -s -XDELETE 'http://localhost:9200/backend2'`;
				print "ElasticSearch delete message: $deleted\n";
			}
		}
	}
	else {
		print "Creating new index failed! Old index still in effect.\n";
                `curl -s -XDELETE 'http://localhost:9200/backend1'`;
		exit;
	}
}

# Update publications index for the time this process took
print "Updating index for the time this process took...\n";
my $command = "$perl_version $sb_home/bin/index_publication.pl -u '$last_indexed'";
my $result = `$command`;
print "Updated the index. DONE!\n\n\n";
