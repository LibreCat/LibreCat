#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu;
use App::Catalogue::Controller::Import qw/arxiv inspire crossref pmc/;
use Data::Dumper;
use YAML;
Catmandu->load(':up');
Catmandu->config;


my $source = $ARGV[0];

my @arxiv = qw(1401.1840 1401.2079 1401.2942 1210.0912 1210.6153 cond-mat/0102536);

my @inspire = qw(1279598 1312532 1312530 1312261);

my @crossref = qw(10.5560/ZNB.2013-2241 10.1371/journal.pcbi.1002986
    10.1088/1475-7516/2013/01/011 10.1109/JSSC.2012.2220671
    10.1007/978-3-319-09764-0_9 10.1016/B978-0-12-401716-0.00038-6
    10.1109/SMC.2014.6973987 10.1145/2617841.2620712
    10.1145/2658861.2658939);
my @pubmed = qw(25053041 25053070 25053097 25148973 25148964 21685572);

# foreach (@pubmed) {
#     print Dumper pmc($_);
# }

# foreach (@inspire) {
#     print Dump inspire($_);
# }

foreach (@crossref) {
   print Dump crossref($_);
}

# foreach (@arxiv) {
#     print Dumper arxiv($_);
# }
