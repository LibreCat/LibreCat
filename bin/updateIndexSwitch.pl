#!/usr/local/env perl

use Catmandu::Sane;
use Catmandu -all;
use Search::Elasticsearch;
use Data::Dumper;

Catmandu->load(':up');
Catmandu->config;

my $backup = Catmandu->store('backup')->bag('publication');

my $e = Search::Elasticsearch->new();

my $index_exists = $e->indices->exists(index => 'pub1');

if ($index_exists) {
	my $bag = Catmandu->store('search', index_name => 'pub2')->bag('publication');
#	print Dumper $backup;
#	exit;
	$bag->add_many($backup);
	$e->indices->update_aliases(
		body => {
			actions => [
				{ add    => { alias => 'pub', index => 'pub2' }},
				{ remove => { alias => 'pub', index => 'pub1' }}
			]
		}
	);
	$e->indices->delete(index => 'pub1');
} else {
	my $bag = Catmandu->store('search', index_name => 'pub1')->bag('publication');
#	print Dumper $backup;
#	exit;
	$bag->add_many($backup);
	$e->indices->update_aliases(
		body => {
			actions => [
				{ add    => { alias => 'pub', index => 'pub1' }},
				{ remove => { alias => 'pub', index => 'pub2' }}
			]
		}
	);
	$e->indices->delete(index => 'pub2');
}

__END__
#my $command_1 = "$perl_version $sb_home/bin/index_publication_convert.pl";#$sb_home/bin/index_publication.pl";
#my $command_2 = "$perl_version $sb_home/bin/index_project.pl";
#my $command_3 = "$perl_version $sb_home/bin/index_researcher.pl";
#my $command_4 = "$perl_version $sb_home/bin/index_award.pl";
#my $command_5 = "$perl_version $sb_home/bin/index_department.pl";
