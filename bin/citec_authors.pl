#!/usr/bin/env perl

use FindBin qw($Bin);
use Catmandu::Sane;
use Catmandu -load;
use Catmandu::Importer::CSV;
use Catmandu::Exporter::JSON;

Catmandu->config(':up');

my $imp = Catmandu::Importer::CSV->new(file => 'citec_authors.csv');
my $exp = Catmandu::Exporter::JSON->new(file => "$Bin/../public/citec_authors.json", array => 1);

my $search_bag = Catmandu->store('search')->bag('publication');

$imp->each(sub {
    my $pers = $_[0];
    $pers->{total} = $search_bag->search(cql_query => "person=$pers->{bis_id}", limit => 10)->total;

    $exp->add($pers);
});
