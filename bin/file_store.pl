#!/usr/bin/env perl

use lib qw(./lib);
use Catmandu::Sane;
use Catmandu::Util;
use Log::Log4perl;
use Log::Any::Adapter;
use Getopt::Long;
use Carp;
use File::Basename;
use Data::Dumper;
use POSIX qw(strftime);
use namespace::clean;

Log::Log4perl::init('log4perl.conf');
Log::Any::Adapter->set('Log4perl');

my $logger     = Log::Log4perl->get_logger('file_store');

my $file_store = 'BagIt';
my $file_opt   = { root => '/data2/librecat/file_uploads' };

GetOptions(
    "file_store|f=s" => \$file_store ,
    "file_opt|o=s"   => \$file_opt ,
);

my $cmd = shift;

usage() unless $cmd;

my $store = load();

if ($cmd eq 'list') {
    cmd_list(@ARGV);
}
elsif ($cmd eq 'add') {
    cmd_add(@ARGV);
}
elsif ($cmd eq 'get') {
    cmd_get(@ARGV);
}
elsif ($cmd eq 'delete') {
    cmd_delete(@ARGV);
}

sub cmd_list {
    my ($key) = @_;

    if ($key) {
        my $ref = $store->get($key);

        croak "list - no such $key bag" unless $ref;

        $ref->list();
    }
    else {
        $store->list(sub {
            my $key = shift;

            my $container = $store->get($key);
            my $created   = $container->created;
            my $modified  = $container->modified;

            my @files = $container->list;

            my $size = 0;

            for (@files) {
                $size += $_->size;
            }

            printf "%-40.40s %4d %9d %-20.20s %-20.20s\n"
                    , $key
                    , int(@files)
                    , $size
                    , strftime("%Y-%m-%dT%H:%M:%S", localtime($modified))
                    , strftime("%Y-%m-%dT%H:%M:%S", localtime($created));
        });
    }
}

sub cmd_get {
    my ($key) = @_;

    croak "get - need a key" unless defined($key);

    my $container = $store->get($key);

    croak "get - failed to load $key bag" unless $container;

    printf "key: %s\n" , $container->key;
    printf "created: %s\n", scalar localtime($container->created);
    printf "modified: %s\n", scalar localtime($container->modified);

    my @files = $container->list;

    printf "#files: %d\n" , int(@files);

    for my $file (@files) {
        my $key      = $file->key;
        my $size     = $file->size;
        my $md5      = $file->md5;
        my $modified = $file->modified;
        printf "%-40.40s %9d $md5 %s\n" 
                , $key
                , $size
                , strftime("%Y-%m-%dT%H:%M:%S", localtime($modified));
    }
}

sub cmd_add {
    my ($key,$file) = @_;
    croak "add - need a key and a file" unless defined($key) && defined($file) && -r $file;

    my $container = $store->get($key);

    croak "add - failed to find $key bag" unless $container;

    my ($name,$path,$suffix) = fileparse($file);

    $container->add($name, IO::File->new("$path/$name"));

    $container->commit;

    cmd_get($key);
}

sub cmd_delete {
    my ($key,$name) = @_;
    croak "delete - need a key and a file" unless defined($key) && defined($name);

    my $container = $store->get($key);

    croak "delete - failed to find $key bag" unless $container;

    $container->delete($name);

    $container->commit;

    cmd_get($key);
}

sub load {
    my $pkg = Catmandu::Util::require_package($file_store,'LibreCat::FileStore');
    $pkg->new(%$file_opt);
}

sub usage {
    print STDERR <<EOF;
usage: $0 [options] cmd

cmds:
    list

options:
    --file_store=... | -f=...
    --file_opt=...   | -o=...

EOF
    exit 1;
}