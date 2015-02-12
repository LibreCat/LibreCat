#!/usr/local/env perl

use Catmandu::Sane;
use Catmandu -all;
use Search::Elasticsearch;

Catmandu->load(':up');
Catmandu->config;

my $backup = Catmandu->store->bag('publication');

my $e = Search::Elasticsearch->new();

my $index_exists = $e->indices->exists(index => 'PUB1');

if ($index_exists) {
	my $bag = Catmandu->store('search', index_name => 'PUB2')->bag('publication');
	$bag->add_many($backup);
	$e->indices->update_aliases(
		body => {
			actions => [
				{ add    => { alias => 'PUB', index => 'PUB2' }},
				{ remove => { alias => 'PUB', index => 'PUB1' }}
			]
		}
	);
	$e->indices->delete(index => 'PUB1');
} else {
	my $bag = Catmandu->store('search', index_name => 'PUB1')->bag('publication');
	$bag->add_many($backup);
	$e->indices->update_aliases(
		body => {
			actions => [
				{ add    => { alias => 'PUB', index => 'PUB1' }},
				{ remove => { alias => 'PUB', index => 'PUB2' }}
			]
		}
	);
	$e->indices->delete(index => 'PUB2');
}

__END__
#my $command_1 = "$perl_version $sb_home/bin/index_publication_convert.pl";#$sb_home/bin/index_publication.pl";
#my $command_2 = "$perl_version $sb_home/bin/index_project.pl";
#my $command_3 = "$perl_version $sb_home/bin/index_researcher.pl";
#my $command_4 = "$perl_version $sb_home/bin/index_award.pl";
#my $command_5 = "$perl_version $sb_home/bin/index_department.pl";
