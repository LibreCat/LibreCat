package LibreCat::Cmd::file_store;

use Catmandu::Sane;
use Catmandu;
use LibreCat::App::Helper;
use LibreCat::Validator::Publication;
use Carp;
use IO::File;
use IO::Pipe;
use File::Basename;
use File::Path;
use File::Spec;
use URI::Escape;
use POSIX qw(strftime);
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat file_store [options] list [recursive]
librecat file_store [options] get <key> [<file>]
librecat file_store [options] add <key> <file>
librecat file_store [options] delete <key> <file>
librecat file_store [options] purge <key>
librecat file_store [options] export <key> <zip>
librecat file_store [options] import <key> <zip>
librecat file_store [options] move <key|store_name> <store_name>

librecat file_store [options] thumbnail <key> <file>

options:
    --store=...       - Store name
    --file_store=...  - Catmandu::Store::File class
    --file_opt=...    - Catmandu::Store::File option
    --tmp_dir=...     - Temporary directory
    --zip=...         - Zip program
    --unzip=...       - Unzip program

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (
        ["store=s",      "store name"],
        ["file_store=s", "store class"],
        ["file_opt=s%",  "store options"],
        [
            "tmp_dir=s",
            "temporary directory",
            {default => $ENV{TMPDIR} || '/tmp'}
        ],
        ["zip=s",   "zipper",   {default => '/usr/bin/zip'}],
        ["unzip=s", "unzipper", {default => '/usr/bin/unzip'}],
        ["csv",     "to CSV (get)"],
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
    my ($self, $file_store, $file_opt) = @_;
    my $pkg
        = Catmandu::Util::require_package($file_store, 'Catmandu::Store::File');
    $pkg->new(%$file_opt);
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands
        = qr/list|exists|get|add|delete|purge|export|import|move|thumbnail/;

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

    $self->app->set_global_options(
        {
            store    => $self->load($file_store, $file_opt),
            tmp_dir  => $opts->tmp_dir,
            zipper   => $opts->zip,
            unzipper => $opts->unzip,
            csv      => $opts->csv,
        }
    );

    binmode(STDOUT, ":encoding(utf-8)");

    if ($cmd eq 'list') {
        return $self->_list(@$args);
    }
    elsif ($cmd eq 'exists') {
        return $self->_exists(@$args);
    }
    elsif ($cmd eq 'get') {
        my ($key, $file) = @$args;
        if (defined($file)) {
            return $self->_fetch($key, $file);
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
    elsif ($cmd eq 'move') {
        return $self->_move(@$args);
    }
    elsif ($cmd eq 'thumbnail') {
        return $self->_thumbnail(@$args);
    }
}

sub _list {
    my ($self, @args) = @_;
    my $store = $self->app->global_options->{store};
    my $index = $store->index;

    if ($self->app->global_options->{csv}) {
        printf join("\t", qw(id file_name access_level relation embargo))
            . "\n";
    }

    $index->each(sub {
        my $key   = $_[0]->{_id};
        my $files = $index->files($key);

        croak "failed to find the files for key `$key`"
            unless defined($files);

        my $file_array = $files->to_array;

        my $modified;
        my $created;
        my $size = 0;

        for (@$file_array) {
            $modified = $_->{modified} if (!defined($modified) || $_->{modified} > $modified);
            $created  = $_->{created}  if (!defined($created) || $_->{created} > $created);
            $size    += $_->{size} // 0;
        }

        $modified //= 0;
        $created  //= 0;

        if ($self->app->global_options->{csv}) {
            for (@$file_array) {
                printf join("\t", $key, $_->{_id}, '', '', '') . "\n";
            }
        }
        else {
            if ($args[0] && $args[0] eq 'recursive') {
                for (@$file_array) {
                    my $file_name     = $_->{_id}  // '';
                    my $file_size     = $_->{size} // 0;
                    my $file_modified = $_->{modified} // 0;
                    my $file_md5      = $_->{md5}  // '';

                    printf "%s %s %s %s %s\n",
                        $key,
                        strftime(
                            "%Y-%m-%dT%H:%M:%S",
                            localtime($file_modified)
                        ),
                        $file_size,
                        $file_md5,
                        $file_name;
                }
            }
            else {
                printf "%-40.40s %4d %9d %-20.20s %-20.20s\n",
                    $key,
                    int(@$file_array),
                    $size,
                    strftime("%Y-%m-%dT%H:%M:%S", localtime($modified)),
                    strftime("%Y-%m-%dT%H:%M:%S", localtime($created));
            }
        }
    });

    return 0;
}

sub _exists {
    my ($self, $key) = @_;

    croak "exists - need a key" unless defined($key);

    my $store = $self->app->global_options->{store};
    my $ans   = $store->index->exists($key);

    printf "$key %s\n", $ans ? "EXISTS" : "NOT_FOUND";

    exit($ans ? 0 : 2);
}

sub _get {
    my ($self, $key) = @_;

    croak "get - need a key" unless defined($key);

    my $store  = $self->app->global_options->{store};

    croak "get - failed to load $key" unless $store->index->exists($key);

    my $files      = $store->index->files($key);
    my $file_array = $files->to_array;

    if ($self->app->global_options->{csv}) {
        printf join("\t", qw(id file_name access_level relation embargo))
            . "\n";

        for my $file (@$file_array) {
            next if $file->{_id} eq 'thumbnail.png';
            printf join("\t", $key, $file->{_id}, '', '', '') . "\n";
        }
    }
    else {
        printf "key: %s\n",      $key;
        printf "#files: %d\n",   int(@$file_array);

        for my $file (@$file_array) {
            my $key          = $file->{_id};
            my $size         = $file->{size} // 0;
            my $md5          = $file->{md5};
            my $modified     = $file->{modified} // 0;
            my $content_type = $file->{content_type} // '???';

            printf "%-40.40s %9d $md5 %s %s\n", $content_type, $size,
                strftime("%Y-%m-%dT%H:%M:%S", localtime($modified)), $key;
        }
    }

    return 0;
}

sub _fetch {
    my ($self, $key, $filename) = @_;

    croak "get - need a key"  unless defined($key);
    croak "get - need a file" unless defined($filename);

    my $store = $self->app->global_options->{store};

    croak "get - failed to load $key" unless $store->index->exists($key);

    my $files = $store->index->files($key);
    my $file  = $files->get($filename);

    croak "get - failed to open $filename" unless $file;

    binmode(STDOUT, ':raw');

    my $bytes = $files->stream(IO::File->new('>&STDOUT'), $file);

    $bytes > 0;
}

sub _add {
    my ($self, $key, $file) = @_;

    croak "add - need a key and a file"
        unless defined($key) && defined($file) && -r $file;

    my $store  = $self->app->global_options->{store};

    my $files;

    if ($store->index->exists($key)) {
        $files = $store->index->files($key);
    }
    else {
        $store->index->add({ _id => $key }) || croak "add - failed to add $key";
        $files = $store->index->files($key);
    }

    croak "add - failed to find or create $key" unless $files;

    my ($name, $path, $suffix) = fileparse($file);

    $files->upload(IO::File->new("<$path/$name"),$name);

    return $self->_get($key);
}

sub _delete {
    my ($self, $key, $name) = @_;

    croak "delete - need a key and a file"
        unless defined($key) && defined($name);

    my $store  = $self->app->global_options->{store};

    croak "delete - failed to find $key" unless $store->index->exists($key);

    my $files  = $store->index->files($key);

    $files->delete($name);

    return $self->_get($key);
}

sub _purge {
    my ($self, $key) = @_;

    croak "purge - need a key" unless defined($key);

    my $store = $self->app->global_options->{store};

    croak "purge - failed to find $key" unless $store->index->exists($key);

    $store->index->delete($key);

    return 0;
}

sub _move {
    my ($self, $key, $name) = @_;

    croak "move - need a key and file_store"
        unless defined($key) && defined($name);

    my $file_store = $self->file_store($name);
    my $file_opt   = $self->file_opt($name);

    croak "move - no `$name` defined as file_store" unless $file_store;

    my $target_store = $self->load($file_store, $file_opt);

    croak "move - can't create `$name` store" unless $target_store;

    my $source_store = $self->app->global_options->{store};

    if (-r $key) {
        local (*F);
        open(F, $key) || croak "move - failed to open `$key` for reading";
        while (<F>) {
            chomp;
            $self->_move_files($source_store, $target_store, $_);
        }
        close(F);
    }
    elsif (my $key_store = $self->file_store($key)) {
        my $key_opt = $self->file_opt($key);
        my $key_store = $self->load($key_store, $key_opt);

        $key_store->index->each(sub {
            my $file = shift;
            my $key  = $file->{_id};
            $self->_move_files($key_store, $target_store, $key);
        });
    }
    else {
        $self->_move_files($source_store, $target_store, $key);
    }

    0;
}

{
    my $_mb_sec_stats = {now => time, total => 0};

    sub _mb_sec {
        my ($self, $bytes) = @_;

        $_mb_sec_stats->{total} += $bytes // 0;

        my $elapsed = (time - $_mb_sec_stats->{now}) || 1;

        return $_mb_sec_stats->{total} / (1000 * 1000 * $elapsed);
    }
}

sub _move_files {
    my ($self, $source_store, $target_store, $key) = @_;

    my $curr_time = sub {
        strftime("%Y-%m-%dT%H:%M:%S", localtime(time));
    };

    printf STDERR "%s [%-3.3f] $key ", $curr_time->(), $self->_mb_sec();

    unless ($source_store->index->exists($key)) {
        print STDERR "ERROR (no $key in source)\n";
        return;
    }

    my $source_files = $source_store->index->files($key);

    my $target_files;

    if ($target_store->index->exists($key)) {
        $target_files = $target_store->index->files($key);
    }
    else {
        $target_store->index->add({ _id => $key })
            || croak "failed to add $key to target";
        $target_files = $target_store->index->files($key);
    }

    print "OK\n";

    $source_files->each(sub {
        my $file = shift;
        my $name = $file->{_id};
        my $size = $file->{size};

        my $pipe = new IO::Pipe;

        if (my $pid = fork()) { # Parent
            $pipe->reader();

            $target_files->upload($pipe,$name) >= 0
                || croak "failed to upload $name : $!";

            waitpid($pid,0);
        }
        else { # Child
            $pipe->writer();
            $source_files->stream($pipe,$file) >= 0
                || croak "failed to stream $name : $!";
            exit(0);
        }

        printf STDERR "%s [%-3.3f] $key/$name\n", $curr_time->(),
            $self->_mb_sec($size);
    });
}

sub _export {
    my ($self, $key, $zip_file) = @_;

    my $workdir = sprintf "%s/.%s", $self->app->global_options->{tmp_dir}, $$;

    croak "export - need a key"           unless defined($key);
    croak "export - need a zip file name" unless defined($zip_file);

    $zip_file = File::Spec->rel2abs($zip_file);

    my $store = $self->app->global_options->{store};

    croak "export - failed to find $key" unless $store->index->exists($key);

    my $files = $store->index->files($key);

    my $export_dir = sprintf "%s/%s", $workdir, $key;

    unless (mkpath($export_dir)) {
        croak "export - failed to create $export_dir";
    }

    my $file_array = $files->to_array;

    for my $file (@$file_array) {
        my $key = $file->{_id};

        $files->stream(IO::File->new("> $export_dir/$key"),$file) ||
            croak "failed to stream key to $export_dir/$key";
    }

    my $zipper = $self->app->global_options->{zipper};

    if (-r $zip_file && !unlink $zip_file) {
        croak "Failed to remove existing $zip_file";
    }

    system("cd $workdir && $zipper -r $zip_file $key/*");

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

    0;
}

sub _import {
    my ($self, $key, $zip_file) = @_;

    my $store = $self->app->global_options->{store};

    $zip_file = File::Spec->rel2abs($zip_file);

    my $workdir = sprintf "%s/.%s", $self->app->global_options->{tmp_dir}, $$;

    croak "import - need a key"           unless defined($key);
    croak "import - need a zip file name" unless defined($zip_file);

    unless (mkpath($workdir)) {
        croak "export - failed to create $workdir";
    }

    my $unzipper = $self->app->global_options->{unzipper};

    $SIG{CHLD} = 'DEFAULT';    # required to avoid 'no child errors';
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
        $self->_add($key, $file);
    }

    unless (File::Path::remove_tree($workdir) > 0) {
        croak "Failed to remove $workdir";
    }

    0;
}

sub _thumbnail {
    my ($self, $key, $filename) = @_;

    croak "get - need a key"  unless defined($key);
    croak "get - need a file" unless defined($filename);

    my $h = LibreCat::App::Helper::Helpers->new;

    my $thumbnailer_package
        = $h->config->{filestore}->{access_thumbnailer}->{package};
    my $thumbnailer_options
        = $h->config->{filestore}->{access_thumbnailer}->{options};

    my $pkg = Catmandu::Util::require_package($thumbnailer_package,
        'LibreCat::Worker');
    my $worker = $pkg->new(%$thumbnailer_options);

    my $response = $worker->work({key => $key, filename => $filename,});

    $response && $response->{ok};
}

sub find_subdirectory {
    my ($directory) = @_;
    my $has_files = 0;

    for my $f (glob("$directory/*")) {
        next if index($f, ".") == 0;
        return $f if -d $f;
        $has_files = 1;
    }

    return $has_files ? $directory : undef;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::file_store - manage librecat file stores

=head1 SYNOPSIS

    librecat file_store list [recursive]
    librecat file_store get <key> [<file>]
    librecat file_store add <key> <file>
    librecat file_store delete <key> <file>
    librecat file_store purge <key>
    librecat file_store export <key> <zip>
    librecat file_store import <key> <zip>
    librecat file_store move <key|store_name> <store_name>

    librecat store thumbnail <key> <file>

    options:
        --store=...       - Store name
        --file_store=...  - Catmandu::Store::File class
        --file_opt=...    - Catmandu::Store::File option
        --tmp_dir=...     - Temporary directory
        --zip=...         - Zip program
        --unzip=...       - Unzip program
=cut
