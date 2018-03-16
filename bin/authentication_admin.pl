#!/usr/bin/env perl

=head1 NAME

authentication_test.pl - Test your authentication settings

=head1 SYNOPSIS

    $ perl bin/authentication_test.pl mylogin -p
    Password: *****
    OK

    $ perl bin/authentication_test.pl
               --package=Authentication::Test
               --param foo=bar
               --param test=ok  mylogin -p
    Password: *****
    OK

=head1 SEE ALSO

L<log4perl.conf>

=cut

use Catmandu::Sane;
use Path::Tiny;
use lib path(__FILE__)->parent->parent->child('lib')->stringify;
use LibreCat qw(:load);
use Catmandu::Util qw(require_package);
use Catmandu;
use Getopt::Long;
use Log::Log4perl;

my $package  = Catmandu->config->{authentication}{package};
my $param    = Catmandu->config->{authentication}{options} // {};
my $password;

my $logger = Log::Log4perl->get_logger('authentication_admin');

GetOptions("package=s" => \$package, "param=s%" => \$param, "p" => \$password);

my $user = shift;

die "usage: $0 [--package=MODULE] [[--param=...]] -p login" unless defined $user;

if ($password) {
    print "Password: ";
    system('/bin/stty', '-echo');
    $password = <>; chop($password);
    system('/bin/stty', 'echo');
}
else {
    die "need a password. Try `$0 -p $user'";
}

my $pkg    = require_package($package);
my $auth   = $pkg->new(%$param);

my $users   = LibreCat->user;
my $userobj = $users->find_by_username($user);
my $verify  = $auth->authenticate( { username => $user , password => $password });

my $exporter = Catmandu->exporter('YAML');

if ($verify) {
    print "OK\n";
    $exporter->add($userobj);
    $exporter->commit;
    exit(0);
}
else {
    print "FAILED\n";
    exit(2);
}
