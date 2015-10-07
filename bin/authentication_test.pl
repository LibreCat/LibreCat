#!/usr/bin/env perl

use lib qw(../lib);
use Catmandu;
use Catmandu::Util;
use Getopt::Long;
use Log::Log4perl;
use Log::Any::Adapter;

my $package  = Catmandu->config->{authentication}->{package};
my $param    = Catmandu->config->{authentication}->{param} // {};
my $password;

Log::Log4perl::init('log4perl.conf');
Log::Any::Adapter->set('Log4perl');

GetOptions("package=s" => \$package, "param=s%" => \$param, "p" => \$password);

my $user  = shift;

die "usage: $0 [--package=MODULE] [[--param=...]] login" unless defined $user;

if ($password) {
	print "Password: ";
	system('/bin/stty', '-echo');
	$password = <>; chop($password);
	system('/bin/stty', 'echo'); 
}

my $pkg    = Catmandu::Util::require_package($package);
my $auth   = $pkg->new(%$param);

my $verify = $auth->authenticate( $user , $password );

if ($verify) {
	print "OK\n";
	exit(0);
}
else {
	print "FAILED\n";
	exit(2);
}