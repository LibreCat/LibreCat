use strict;
use warnings;
use Test::More;
use Test::Exception;
use YAML;

my $pkg;
BEGIN {
    $pkg = 'App::Catalogue::Controller::Importer';
    use_ok $pkg;
}
require_ok $pkg;

dies_ok { $pkg->new(source => 'bla') } "dies ok";

lives_ok { $pkg->new(id => '1234') } "lives ok";

my $rec = $pkg->new(id => '10.3389/fmars.2015.00020', source => 'crossref')->fetch;

is $rec->{doi}, '10.3389/fmars.2015.00020', 'doi';

my $rec2 =$pkg->new({id => '1103.3126', source => 'arxiv'})->fetch;

is $rec2->{external_id}->{arxiv}, '1103.3126', 'arxiv';

done_testing;
