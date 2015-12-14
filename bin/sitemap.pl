#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu;

Catmandu->load;
my $conf = Catmandu->config;

my $bag = Catmandu->store('search')->bag('publication');

$bag->each( sub {
	my $rec = $_[0];
    my $type = ($rec->{type} eq 'researchData') ? 'data' : 'publication';
	say "$conf->{host}/$type/$rec->{id}";
    });

#TODO: add person profile pages

=head1 NAME

sitemap.pl

=head1 SYNOPSIS

$ ./createSitemap.pl > ../public/pub_index.txt

=cut
