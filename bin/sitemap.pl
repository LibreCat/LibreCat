#!/usr/bin/env perl

BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    LibreCat::Layers->new->load;
};

use Catmandu::Sane;
use Catmandu;

my $conf = Catmandu->config;
my $bag = Catmandu->store('search')->bag('publication');

$bag->each( sub {
    my $rec = $_[0];
    next unless $rec->{status} && $rec->{status} eq 'public';

    my $type = ($rec->{type} eq 'researchData') ? 'data' : 'publication';
    say "$conf->{host}/$type/$rec->{_id}";
});

#TODO: add person profile pages

=head1 NAME

sitemap.pl

=head1 SYNOPSIS

$ ./createSitemap.pl > ../public/pub_index.txt

=cut
