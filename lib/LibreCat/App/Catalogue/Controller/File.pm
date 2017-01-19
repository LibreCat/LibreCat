package LibreCat::App::Catalogue::Controller::File;

=head1 NAME LibreCat::App::Catalogue::Controller::File

Helper methods for handling file uploads.

=cut

use Catmandu::Sane;
use Catmandu::Util;
use Catmandu;
use LibreCat::App::Helper;
use Dancer::FileUtils qw/path dirname/;
use Dancer ':syntax';
use Data::Uniqid;
use File::Copy;
use Carp;
use Encode qw(decode encode);
use Clone 'clone';
use JSON::MaybeXS qw(decode_json encode_json);
use Exporter qw/import/;

our @EXPORT = qw/handle_file upload_temp_file/;

=head1 METHODS

=head2 upload_temp_file(params->{file},$creator)

Given an upload file handle and a creator string this function will create a
temporary storage file for the upload. Returns a JSON document containing the
file details:

    {
        # Fields needed for managing the upload
        'tempid'       => 'LJCyFMzwjN',
        'file_name'    => 'find.gif',

        # Metadata fields that can be overwritten by the user
        'access_level' => 'open_access',
        'open_access'  => 1,
        'relation'     => 'main_file',

        # Read-only fields
        'content_type' => 'image/gif',
        'creator'      => 'einstein',
        'date_created' => '2016-05-31T11:05:22Z',
        'date_updated' => '2016-05-31T11:05:22Z',
        'file_size'    => '66658',

        # Success/failure indicator
        'success'      => 1,
    }

=cut

sub upload_temp_file {
    my ($file, $creator) = @_;

    h->log->debug("new upload by: $creator");

    unless ($file && $creator) {
        return {
            success       => 0,
            error_message => 'Sorry! The file upload failed.'
        };
    }

    # Gather all file metadata...
    my $now          = h->now;
    my $tempid       = Data::Uniqid::uniqid;
    my $temp_file    = $file->{tempname};
    my $file_name    = $file->{filename};
    my $file_size    = int($file->{size});
    my $content_type = $file->{headers}->{"Content-Type"};

    h->log->info(
        "upload: $file_name ($content_type: $file_size bytes) by $creator");

    my $file_data = {
        file_name    => $file_name,
        file_size    => $file_size,
        tempid       => $tempid,
        content_type => $content_type,
        access_level => "open_access",
        open_access  => 1,
        relation     => "main_file",
        creator      => $creator,
        date_updated => $now,
        date_created => $now,
    };

    # Creating a new temporary storage for the upload files...
    my $filedir = path(h->config->{filestore}->{tmp_dir}, $tempid);

    h->log->info("creating $filedir");

    unless (mkdir $filedir) {
        h->log->error("creating $filedir failed : $!");
        return {
            success       => 0,
            error_message => 'Sorry! The file upload failed.'
        };
    }

    # Copy the upload into the new temporary storage...
    my $filepath
        = path(h->config->{filestore}->{tmp_dir}, $tempid, $file->{filename});

    h->log->info("copy $temp_file to $filepath");

    if (copy($temp_file, $filepath)) {

        # Required for showing a success upload in the web interface
        $file_data->{success} = 1;
    }
    else {
        h->log->error("failed to copy $temp_file to $filepath");
        return {
            success       => 0,
            error_message => 'Sorry! The file upload failed.'
        };
    }

    # Store a copy of the file metadata next to the upload file...
    my $config_file = "$filepath.json";

    h->log->info("storing file metadata to $config_file");

    my $exporter = Catmandu->exporter('JSON', file => $config_file);
    $exporter->add($file_data);
    $exporter->commit;

    h->log->debug("deleting $temp_file");
    unlink $temp_file;

    return $file_data;
}

=head2 handle_file($pub)

For the given publication HASH update the file section (upload files,
generate thumbnails) when required. Metadata (but not the technical
metadata) of existing files will be changed when required. New
files should at least contain 'tempid' and 'file_name'

=cut

sub handle_file {
    my $pub = shift;
    my $key = $pub->{_id};

    h->log->info("updating file metadata for record $key");

    $pub->{file} = _decode_file($pub->{file});

    my $prev_pub = h->publication->get($key);

    # Delete files that are not needed
    for my $fi (_find_deleted_files($prev_pub, $pub)) {
        h->log->debug("deleted " . $fi->{file_name});
        _remove_file($key, $fi->{file_name});
        _remove_thumbnail($key, $fi->{file_name});
    }

    my $count = 0;

    for my $fi (@{$pub->{file}}) {

        # Generate a new file_id if not one existed
        $fi->{file_id} = h->new_record('publication') if !$fi->{file_id};

        h->log->debug("processing file-id: " . $fi->{file_id});

        # If we have a tempid, then there is a file upload waiting...
        if ($fi->{tempid}) {
            my $filename = $fi->{file_name};
            my $path     = path(h->config->{filestore}->{tmp_dir},
                $fi->{tempid}, $filename);

            h->log->info("new upload with temp-id -> $path");
            _make_file($key, $filename, $path);

            h->log->debug(
                "retrieving and updating technical metadata from cache");
            _update_tech_metadata($fi, $filename, $path);
        }

        # Regenerate the first thumbnail...
        if ($count == 0) {
            _make_thumbnail($key, $fi->{file_name});
        }

        # Update the stored metadata fields with the new ones
        _update_file_metadata($fi, $prev_pub);

        delete $fi->{tempid} if $fi->{tempid};

        $count++;
    }
}

=head2 update_file($file)

Update one $pub->{file}->[<item>] with technical metadata found in
the file store. Returns the updated file on success or undef on
failure.

=cut

sub update_file {
    my ($key, $data) = @_;
    my $file     = clone($data);
    my $filename = $file->{file_name};

    unless ($filename) {
        h->log->error("need a filename for update_file for record $key");
        return undef;
    }

    h->log->info("updating $filename for record $key");

    my $file_store = h->config->{filestore}->{default}->{package};
    my $file_opt   = h->config->{filestore}->{default}->{options};

    my $pkg
        = Catmandu::Util::require_package($file_store, 'LibreCat::FileStore');
    my $store = $pkg->new(%$file_opt);

    h->log->info("loading container $key");
    my $container = $store->get($key);

    unless ($container) {
        h->log->error("container $key not found");
        return undef;
    }

    my $res = $container->get($filename);

    unless ($res) {
        h->log->error("file $filename not found in container $key");
        return undef;
    }

    $file->{file_size}    = int($res->{size});
    $file->{content_type} = $res->{content_type};
    $file->{date_created} = h->now($res->{created});
    $file->{date_updated} = h->now($res->{modified});
    $file->{creator} //= 'system';
    $file->{file_id} //= h->new_record('publication');

    $file->{access_level} //= 'open_access';
    $file->{open_access}  //= 1;
    $file->{relation}     //= 'main_file';

    return $file;
}

sub _make_thumbnail {
    my ($key, $filename) = @_;

    h->log->info("creating thumbnail for $filename in record $key");

    unless (h->config->{filestore}->{access_thumbnailer}) {
        h->log->info("no access_thumbnailer defined");
        return undef;
    }

    my $thumbnailer_package
        = h->config->{filestore}->{access_thumbnailer}->{package};
    my $thumbnailer_options
        = h->config->{filestore}->{access_thumbnailer}->{options};

    my $pkg    = Catmandu::Util::require_package($thumbnailer_package);
    my $worker = $pkg->new(%$thumbnailer_options);

    $worker->work({key => $key, filename => $filename});
}

sub _make_file {
    my ($key, $filename, $path) = @_;

    h->log->info("moving $path/$filename to filestore for record $key");

    my $uploader_package = h->config->{filestore}->{uploader}->{package};
    my $uploader_options = h->config->{filestore}->{uploader}->{options};

    my $pkg    = Catmandu::Util::require_package($uploader_package);
    my $worker = $pkg->new(%$uploader_options);

    $worker->work({key => $key, filename => $filename, path => $path,});
}

sub _remove_thumbnail {
    my ($key, $filename) = @_;

    h->log->info("deleting $filename thumbnail for record $key");

    unless (h->config->{filestore}->{access_thumbnailer}) {
        h->log->info("no access_thumbnailer defined");
        return undef;
    }

    my $thumbnailer_package
        = h->config->{filestore}->{access_thumbnailer}->{package};
    my $thumbnailer_options
        = h->config->{filestore}->{access_thumbnailer}->{options};

    my $pkg    = Catmandu::Util::require_package($thumbnailer_package);
    my $worker = $pkg->new(%$thumbnailer_options);

    $worker->work({key => $key, filename => $filename, delete => 1});
}

sub _remove_file {
    my ($key, $filename) = @_;

    h->log->info("deleting $filename for record $key");

    my $uploader_package = h->config->{filestore}->{uploader}->{package};
    my $uploader_options = h->config->{filestore}->{uploader}->{options};

    my $pkg    = Catmandu::Util::require_package($uploader_package);
    my $worker = $pkg->new(%$uploader_options);

    $worker->work({key => $key, filename => $filename, delete => 1});
}

sub _decode_file {
    my $file = shift;
    $file = []      unless defined $file;
    $file = [$file] unless ref($file) eq 'ARRAY';
    for my $fi (@$file) {
        if (ref $fi ne 'HASH') {
            $fi = encode("utf8", $fi);
            $fi = decode_json($fi);
        }

    }
    $file;
}

sub _update_tech_metadata {
    my ($fi, $filename, $path) = @_;

    h->log->debug("updating the technical metadata");

    my $config_file = "$path.json";

    unless (-r $config_file) {
        h->log->error("no cached config file $config_file found!");
        return undef;
    }

    my $importer = Catmandu->importer('JSON', file => $config_file);
    my $data = $importer->first;

    my $administrative_fields = h->config->{forms}->{dropzone_fields}->{administrative} // [];

    for my $name (@$administrative_fields) {
        my $value = $data->{$name};
        h->log->debug("setting $name = " . ($value ? $value : 'null') . " for $filename");
        $fi->{$name} = $value if $value;
    }

    return 1;
}

sub _update_file_metadata {
    my ($fi, $pub) = @_;

    h->log->debug("updating the file metadata");

    return unless $fi;
    return unless $pub;

    my ($prev_fi) = grep {$_->{file_id} eq $fi->{file_id}} @{$pub->{file}};

    my $administrative_fields = h->config->{forms}->{dropzone_fields}->{administrative} // [];
    my $descriptive_fields    = h->config->{forms}->{dropzone_fields}->{descriptive} // [];

    # Throw away the unimportant stuff
    for my $name (keys %$fi) {
        if (grep(/^$name$/, @$administrative_fields)) {
            # do nothing
        }
        elsif (!grep(/^$name$/, @$descriptive_fields)) {
            h->log->debug("...deleting $name from file (unknown field)");
            delete $fi->{$name};
        }
        elsif (!defined $fi->{$name}) {
            h->log->debug("...deleting $name from file (null field)");
            delete $fi->{$name};
        }
    }

    # Keep important stuff that can be written only once
    if ($prev_fi) {
        for my $name (@$administrative_fields) {
            $fi->{$name} = $prev_fi->{$name};
        }
    }

    $fi->{open_access}  = $fi->{access_level} eq 'open_access' ? 1 : 0;
    $fi->{date_created} = h->now unless $fi->{date_created};
    $fi->{date_updated} = h->now;
}

# Find deleted files. Filter out the ones where more than one pub->file
# points to the same file.
sub _find_deleted_files {
    my ($prev, $curr) = @_;

    return () unless defined($prev) && defined($curr);

    my %curr_ids = map {$_->{file_id} // 'undef' => 1} @{$curr->{file}};

    my @deleted_files = ();

    my %prev_names = map {$_->{file_name} => 0} @{$prev->{file}};

    for my $fi (@{$prev->{file}}) {
        my $name = $fi->{file_name};
        my $id   = $fi->{file_id};

        $prev_names{$name} += 1;

        unless (exists $curr_ids{$id}) {
            push @deleted_files, $fi;
            $prev_names{$name} -= 1;
        }
    }

    my @filtered_files = ();

    for my $fi (@deleted_files) {
        my $name = $fi->{file_name};
        push @filtered_files, $fi if $prev_names{$name} == 0;
    }

    return @filtered_files;
}

1;
