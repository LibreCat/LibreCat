#!/usr/bin/env perl

use lib qw(../lib);
use Authentication::Authenticate;

my @ar = @ARGV;
use YAML;
print Dump $ar[1];

my $res = verifyUser($ar[0], $ar[1]);


#print Dump $res;