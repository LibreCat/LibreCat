#!/usr/bin/env perl

use strict;
use warnings;
use lib
  qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /opt/devel/unibi/sbcat/utils/pubSearch/lib);

use lib qw(/srv/www/app-catalog/lib);

#use Dancer ':syntax';
use Template;
use Catmandu -all;
use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Catmandu::Store::ElasticSearch;
use App::Catalog::Helper;
use SBCatDB;
use luurCfg;
use Orms;
use Data::Dumper;
use Catmandu::Store::MongoDB;

my $cfg     = luurCfg->new;
my $orm     = $cfg->{ormsCfg};
my $sbcatDB = SBCatDB->new(
        {
                config_file => "/srv/www/sbcat/conf/extension/sbcatDb.pl",
                db_name     => $orm->{ormsDb},
                host        => $orm->{ormsDbHost},
                username    => $orm->{ormsDbUser},
                password    => $orm->{ormsDbPassword},
        }
   );


#my $results       = $sbcatDB->get('2629103');
#print Dumper $results; exit;

#my $cfg     = luurCfg->new;
#my $orm     = $cfg->{ormsCfg};


Catmandu->load;
my $conf = Catmandu->config;
my $bag = Catmandu->store('search')->bag('researcher');

my $cql = $ARGV[0];
my $hits = $bag->search(
                cql_query    => $cql ,
                #sru_sortkeys => "publishingYear,,0 dateLastChanged,,0",
                limit        => '150',
                start        => '0',
                );

print Dumper $hits;
