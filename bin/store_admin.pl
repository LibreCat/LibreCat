#!/usr/bin/env perl

use lib qw(./lib);
use Catmandu::Sane;
use Catmandu::Util;
use Catmandu;
use Log::Log4perl;
use Log::Any::Adapter;
use Getopt::Long;
use Carp;
use File::Basename;
use File::Path;
use File::Spec;
use Data::Dumper;
use REST::Client;
use URI::Escape;
use POSIX qw(strftime);
use namespace::clean;

Log::Log4perl::init('log4perl.conf');
Log::Any::Adapter->set('Log4perl');

my $logger     = Log::Log4perl->get_logger('store_admin');

my $conf       = Catmandu->config;
my $file_store = $conf->{filestore}->{package};
my $file_opt   = $conf->{filestore}->{options};
my $zipper     = '/usr/bin/zip';
my $unzipper   = '/usr/bin/unzip';
my $tmp_dir    = $ENV{TMPDIR} || '/tmp';
my $storename;

GetOptions(
    "file_store|f=s" => \$file_store ,
    "file_opt|o=s%"  => \$file_opt ,
    "tmp_dir|t=s%"   => \$tmp_dir ,
    "F=s" => \$storename
);

if (defined $storename && exists $conf->{"${storename}store"}) {
    $file_store = $conf->{"${storename}store"}->{package};
    $file_opt   = $conf->{"${storename}store"}->{options};
}

my $cmd = shift;

usage() unless $cmd;

my $store = load($file_store,$file_opt);

if ($cmd eq 'list') {
    cmd_list(@ARGV);
}
elsif ($cmd eq 'exists') {
    cmd_exists(@ARGV);
}
elsif ($cmd eq 'add') {
    cmd_add(@ARGV);
}
elsif ($cmd eq 'get') {
    my ($key,$file) = @ARGV;
    if (defined($file)) {
        cmd_fetch($key,$file);
    } 
    else {
        cmd_get($key);
    }
}
elsif ($cmd eq 'delete') {
    cmd_delete(@ARGV);
}
elsif ($cmd eq 'purge') {
    cmd_purge(@ARGV);
}
elsif ($cmd eq 'export') {
    my ($key,$file) = @ARGV;
    cmd_export($key,$file);
}
elsif ($cmd eq 'import') {
    my ($key,$file) = @ARGV;
    cmd_import($key,$file);
}
elsif ($cmd eq 'thumbnail') {
    my ($key,$file) = @ARGV;
    cmd_thumbnail($key,$file);
}
else {
    print STDERR "unknown command - $cmd\n";
    exit(1);
}

sub cmd_list {
    my (@args) = @_;
    my $gen = $store->list;

    while (my $key = $gen->()) {
        my $container = $store->get($key);
        my $created   = $container->created;
        my $modified  = $container->modified;

        my @files = $container->list;

        my $size = 0;

        for (@files) {
            $size += $_->size;
        }

        if ($args[0] && $args[0] eq 'recursive') {
            for (@files) {
                printf "%s %s\n" , $key , $_->key;
            }
        }
        else {
            printf "%-40.40s %4d %9d %-20.20s %-20.20s\n"
                , $key
                , int(@files)
                , $size
                , strftime("%Y-%m-%dT%H:%M:%S", localtime($modified))
                , strftime("%Y-%m-%dT%H:%M:%S", localtime($created));
        }
    }
}

sub cmd_exists {
    my ($key) = @_;

    croak "exists - need a key" unless defined($key);

    my $ans = $store->exists($key);

    printf "$key %s\n" , $ans ? "EXISTS" : "NOT_FOUND";

    exit($ans ? 0 : 2);
}

sub cmd_get {
    my ($key) = @_;

    croak "get - need a key" unless defined($key);

    my $container = $store->get($key);

    croak "get - failed to load $key" unless $container;

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

sub cmd_fetch {
    my ($key,$filename) = @_;

    croak "get - need a key" unless defined($key);
    croak "get - need a file" unless defined($filename);

    my $container = $store->get($key);

    croak "get - failed to load $key" unless $container;

    my $file = $container->get($filename);

    my $io = $file->fh;

    while (! $io->eof) {
        my $buffer;
        my $len = $io->read($buffer,1024);
        syswrite(STDOUT,$buffer,$len);
    }
}

sub cmd_add {
    my ($key,$file) = @_;
    croak "add - need a key and a file" unless defined($key) && defined($file) && -r $file;

    my $container = $store->get($key);

    unless ($container) {
        $container = $store->add($key);
    }

    croak "add - failed to find or create $key" unless $container;

    my ($name,$path,$suffix) = fileparse($file);

    $container->add($name, IO::File->new("$path/$name"));

    $container->commit;

    cmd_get($key);
}

sub cmd_delete {
    my ($key,$name) = @_;
    croak "delete - need a key and a file" unless defined($key) && defined($name);

    my $container = $store->get($key);

    croak "delete - failed to find $key" unless $container;

    $container->delete($name);

    $container->commit;

    cmd_get($key);
}

sub cmd_purge {
    my ($key) = @_;
    croak "delete - need a key" unless defined($key);

    my $container = $store->get($key);

    croak "delete - failed to find $key" unless $container;

    $store->delete($key);
}

sub cmd_export {
    my ($key,$zip_file) = @_;

    my $workdir = sprintf "%s/.%s" , $tmp_dir , $$;

    croak "export - need a key" unless defined($key);
    croak "export - need a zip file name" unless defined($zip_file);

    my $container = $store->get($key);

    croak "export - failed to find $key" unless $container;

    my $export_name = $container->key;
    my $export_dir  = sprintf "%s/%s" , $workdir , $export_name;

    $logger->info("Creating export directory $export_dir...");

    unless ( mkpath($export_dir) ) {
        $logger->error("Failed to create $export_dir");
        croak "export - failed to create $export_dir";
    }

    my @files = $container->list;

    local(*OUT);

    for my $file (@files) {
        my $key = $file->key;

        $logger->info("Retrieving $key from store...");

        my $obj = $container->get($key);
        my $io  = $obj->fh;

        $logger->error("Writing $export_dir/$key");

        open(OUT,"> $export_dir/$key");
        binmode(OUT,':raw');

        while (! $io->eof) {
            my $buffer;
            my $len = $io->read($buffer,1024);
            syswrite(OUT,$buffer,1024);
        }

        close (OUT);
    }

    $logger->info("Zipping $export_dir into $zip_file...");
    system("cd $workdir && $zipper -r $zip_file $export_name/*");

    if ($? == -1) {
        $logger->error("Failed to execute $zipper");
        croak "Failed to execute $zipper";
    }
    elsif ($? & 127) { 
        $logger->error("Zipper $zipper died, core dumped");
        croak "Zipper $zipper died, core dumped";
    }
    elsif ($? != 0) {
        my $val = $? >> 8;
        $logger->error("Zipper $zipper died, exit code $val");
        croak "Zipper $zipper died, exit code $val";
    }

    $logger->info("Removing work directory $workdir");

    unless (File::Path::remove_tree($workdir) > 0) {
        $logger->error("Failed to remove $workdir");
        croak "Failed to remove $workdir";
    }

    1;
}

sub cmd_import {
    my ($key,$zip_file) = @_;

    $zip_file = File::Spec->rel2abs($zip_file);

    my $workdir = sprintf "%s/.%s" , $tmp_dir , $$;

    croak "import - need a key" unless defined($key);
    croak "import - need a zip file name" unless defined($zip_file);

    my $container = $store->get($key);

    croak "import - container $key already exists" if $container;

    $logger->info("Creating import directory $workdir...");

    unless ( mkpath($workdir) ) {
        $logger->error("Failed to create $workdir");
        croak "export - failed to create $workdir";
    }

    $logger->info("Extracting files from $zip_file");
    system("cd $workdir && $unzipper $zip_file");

    if ($? == -1) {
        $logger->error("Failed to execute $unzipper");
        croak "Failed to execute $unzipper";
    }
    elsif ($? & 127) { 
        $logger->error("Zipper $unzipper died, core dumped");
        croak "Zipper $unzipper died, core dumped";
    }
    elsif ($? != 0) {
        my $val = $? >> 8;
        $logger->error("Zipper $unzipper died, exit code $val");
        croak "Zipper $unzipper died, exit code $val";
    }

    my $zip_directory = find_subdirectory($workdir);

    unless ($zip_directory) {
        $logger->error("Can't find a zip_directory");
        croak "Can't find a zip_directory";
    }

    $logger->info("Zip dirctory for import $zip_directory...");

    for my $file (glob("$zip_directory/*")) {
        $logger->info("Adding $file to container $key...");
        cmd_add($key,$file);
    }

    $logger->info("Removing work directory $workdir");
    
    unless (File::Path::remove_tree($workdir) > 0) {
        $logger->error("Failed to remove $workdir");
        croak "Failed to remove $workdir";
    }

    1;
}

sub cmd_thumbnail {
    my ($key,$filename) = @_;

    croak "get - need a key" unless defined($key);
    croak "get - need a file" unless defined($filename);

    my $client = REST::Client->new();
    my $url = sprintf "%s/librecat/api/access/%s/%s/thumbnail" 
                    , $conf->{host}
                    , uri_escape($key)
                    , uri_escape($filename);
    $client->POST($url);

    unless ($client->responseCode() eq '200') {
        print STDERR "Failed to create a thumbail for $key $filename\n";
        print STDERR $client->responseContent();
        exit(2);
    }
}

sub find_subdirectory {
    my ($directory) = @_;
    my $has_files = 0;

    for my $f (glob("$directory/*")) {
        next if index($f,".") == 0;
        return $f if -d $f;
        $has_files = 1;
    }

    return $has_files ? $directory : undef;
}

sub load {
    my ($file_store,$file_opt) = @_;
    my $pkg = Catmandu::Util::require_package($file_store,'LibreCat::FileStore');
    $pkg->new(%$file_opt);
}

sub usage {
    print STDERR <<EOF;
usage: $0 [options] cmd

cmds:
  {lowlevel}
    list [recursive]
    get <key> [<file>]
    add <key> <file>
    delete <key> <file>
    purge <key>
    export <key> <zip>
    import <key> <zip>

  {using the REST api}
    thumbnail <key> <file>

options:
    -F storename
    --file_store=... | -f=...
    --file_opt=...   | -o=...
    --tmp_dir=...    | -t=...

EOF
    exit 1;
}