package LibreCat::Cmd::store;

use Catmandu::Sane;
use Catmandu;
use App::Helper;
use LibreCat::Validator::Publication;
use Carp;
use IO::File;
use File::Basename;
use File::Path;
use File::Spec;
use Data::Dumper;
use REST::Client;
use URI::Escape;
use POSIX qw(strftime);
use parent qw(LibreCat::Cmd);

sub description {
	return <<EOF;
Usage:

librecat store [options] list [recursive]
librecat store [options] get <key> [<file>]
librecat store [options] add <key> <file>
librecat store [options] delete <key> <file>
librecat store [options] purge <key>
librecat store [options] export <key> <zip>
librecat store [options] import <key> <zip>

librecat store [options] thumbnail <key> <file>
EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (
        [ "store=s", "store name" ],
        [ "file_store=s", "store class" ],
        [ "file_opt=s%", "store options" ],
        [ "tmp_dir=s", "temporary directory" , { default => $ENV{TMPDIR} || '/tmp' } ],
        [ "zip=s" , "zipper" , { default => '/usr/bin/zip' }],
        [ "unzip=s" , "unzipper" , { default => '/usr/bin/unzip' }],
    );
}

sub file_store {
    my $self = shift;
    my $name = shift // 'default';
	Catmandu->config->{filestore}->{$name}->{package};
}

sub file_opt {
    my $self = shift;
    my $name = shift // 'default';
	Catmandu->config->{filestore}->{$name}->{options};
}

sub load {
    my ($self,$file_store,$file_opt) = @_;
    my $pkg = Catmandu::Util::require_package($file_store,'LibreCat::FileStore');
    $pkg->new(%$file_opt);
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/list|exists|get|add|delete|purge|export|import/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    my $file_store = $opts->file_store;
    my $file_opt   = $opts->file_opt;

    if (my $file_store_name = $opts->store) {
        $file_store = $self->file_store($file_store_name);
        $file_opt   = $self->file_opt($file_store_name);

        unless ($file_store) {
            print STDERR "no such store '$file_store_name'\n";
            exit(2);
        }
    }

    unless ($file_store) {
        $file_store = $self->file_store;
    }

    unless ($file_opt) {
        $file_opt = $self->file_opt;
    }

    $self->app->set_global_options({
    		store    => $self->load($file_store,$file_opt) ,
    		tmp_dir  => $opts->tmp_dir ,
    		zipper   => $opts->zip ,
    		unzipper => $opts->unzip ,
    });

    if ($cmd eq 'list') {
    	return $self->_list(@$args);
    }
    elsif ($cmd eq 'exists') {
    	return $self->_exists(@$args);
    }
    elsif ($cmd eq 'get') {
	   	my ($key,$file) = @$args;
	    if (defined($file)) {
	        return $self->_fetch($key,$file);
	    }
	    else {
	        return $self->_get($key);
	    }
    }
    elsif ($cmd eq 'add') {
    	return $self->_add(@$args);
    }
    elsif ($cmd eq 'delete') {
    	return $self->_delete(@$args);
    }
	elsif ($cmd eq 'purge') {
    	return $self->_purge(@$args);
    }
    elsif ($cmd eq 'export') {
    	return $self->_export(@$args);
    }
    elsif ($cmd eq 'import') {
    	return $self->_import(@$args);
    }
    elsif ($cmd eq 'thumbnail') {
    	return $self->_thumbnail(@$args);
    }
}

sub _list {
    my ($self,@args) = @_;
    my $store = $self->app->global_options->{store};
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

sub _exists {
    my ($self,$key) = @_;

    croak "exists - need a key" unless defined($key);

	my $store = $self->app->global_options->{store};
    my $ans = $store->exists($key);

    printf "$key %s\n" , $ans ? "EXISTS" : "NOT_FOUND";

    exit($ans ? 0 : 2);
}

sub _get {
    my ($self,$key) = @_;

    croak "get - need a key" unless defined($key);

	my $store = $self->app->global_options->{store};
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
        my $content_type = $file->content_type // '???';

        printf "%-40.40s %9d $md5 %s %s\n"
                , $content_type
                , $size
                , strftime("%Y-%m-%dT%H:%M:%S", localtime($modified))
                , $key;
    }
}

sub _fetch {
    my ($self,$key,$filename) = @_;

    croak "get - need a key" unless defined($key);
    croak "get - need a file" unless defined($filename);

	my $store = $self->app->global_options->{store};
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

sub _add {
    my ($self,$key,$file) = @_;

    croak "add - need a key and a file" unless defined($key) && defined($file) && -r $file;

	my $store = $self->app->global_options->{store};
    my $container = $store->get($key);

    unless ($container) {
        $container = $store->add($key);
    }

    croak "add - failed to find or create $key" unless $container;

    my ($name,$path,$suffix) = fileparse($file);

    $container->add($name, IO::File->new("$path/$name"));

    $container->commit;

    return $self->_get($key);
}

sub _delete {
    my ($self,$key,$name) = @_;

    croak "delete - need a key and a file" unless defined($key) && defined($name);

	my $store = $self->app->global_options->{store};
    my $container = $store->get($key);

    croak "delete - failed to find $key" unless $container;

    $container->delete($name);

    $container->commit;

    return $self->_get($key);
}

sub _purge {
    my ($self,$key) = @_;

    croak "delete - need a key" unless defined($key);

	my $store = $self->app->global_options->{store};
    my $container = $store->get($key);

    croak "delete - failed to find $key" unless $container;

    $store->delete($key);
}

sub _export {
    my ($self,$key,$zip_file) = @_;

    my $workdir = sprintf "%s/.%s" , $self->app->global_options->{tmp_dir} , $$;

    croak "export - need a key" unless defined($key);
    croak "export - need a zip file name" unless defined($zip_file);

	my $store = $self->app->global_options->{store};
    my $container = $store->get($key);

    croak "export - failed to find $key" unless $container;

    my $export_name = $container->key;
    my $export_dir  = sprintf "%s/%s" , $workdir , $export_name;

    unless ( mkpath($export_dir) ) {
        croak "export - failed to create $export_dir";
    }

    my @files = $container->list;

    local(*OUT);

    for my $file (@files) {
        my $key = $file->key;

        my $obj = $container->get($key);
        my $io  = $obj->fh;

        open(OUT,"> $export_dir/$key");
        binmode(OUT,':raw');

        while (! $io->eof) {
            my $buffer;
            my $len = $io->read($buffer,1024);
            syswrite(OUT,$buffer,1024);
        }

        close (OUT);
    }

    my $zipper = $self->app->global_options->{zipper};

    system("cd $workdir && $zipper -r $zip_file $export_name/*");

    if ($? == -1) {
        croak "Failed to execute $zipper";
    }
    elsif ($? & 127) {
        croak "Zipper $zipper died, core dumped";
    }
    elsif ($? != 0) {
        my $val = $? >> 8;
        croak "Zipper $zipper died, exit code $val";
    }

    unless (File::Path::remove_tree($workdir) > 0) {
        croak "Failed to remove $workdir";
    }

    1;
}

sub _import {
    my ($self,$key,$zip_file) = @_;

	my $store = $self->app->global_options->{store};

    $zip_file = File::Spec->rel2abs($zip_file);

    my $workdir = sprintf "%s/.%s" , $self->app->global_options->{tmp_dir} , $$;

    croak "import - need a key" unless defined($key);
    croak "import - need a zip file name" unless defined($zip_file);

    my $container = $store->get($key);

    croak "import - container $key already exists" if $container;

    unless ( mkpath($workdir) ) {
        croak "export - failed to create $workdir";
    }

    my $unzipper = $self->app->global_options->{unzipper};

    system("cd $workdir && $unzipper $zip_file");

    if ($? == -1) {
        croak "Failed to execute $unzipper";
    }
    elsif ($? & 127) {
        croak "Zipper $unzipper died, core dumped";
    }
    elsif ($? != 0) {
        my $val = $? >> 8;
        croak "Zipper $unzipper died, exit code $val";
    }

    my $zip_directory = find_subdirectory($workdir);

    unless ($zip_directory) {
        croak "Can't find a zip_directory";
    }

    for my $file (glob("$zip_directory/*")) {
        $self->_add($key,$file);
    }

    unless (File::Path::remove_tree($workdir) > 0) {
        croak "Failed to remove $workdir";
    }

    1;
}

sub _thumbnail {
    my ($self,$key,$filename) = @_;

    croak "get - need a key" unless defined($key);
    croak "get - need a file" unless defined($filename);

	my $store = $self->app->global_options->{store};
    my $client = REST::Client->new();
    my $url = sprintf "%s/librecat/api/access/%s/%s/thumbnail"
                    , Catmandu->config->{host}
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


1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::store - manage librecat stores

=head1 SYNOPSIS

    librecat store list [recursive]
    librecat store get <key> [<file>]
    librecat store add <key> <file>
    librecat store delete <key> <file>
    librecat store purge <key>
    librecat store export <key> <zip>
    librecat store import <key> <zip>

    librecat store thumbnail <key> <file>

=cut
