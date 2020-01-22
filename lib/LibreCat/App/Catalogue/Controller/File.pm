package LibreCat::App::Catalogue::Controller::File;

=head1 NAME LibreCat::App::Catalogue::Controller::File

Helper methods for handling file uploads.

=cut

use Catmandu::Sane;
use Catmandu;
use LibreCat qw(publication timestamp);
use LibreCat::App::Helper;
use Dancer::FileUtils;
use Dancer ':syntax';
use Data::Uniqid;
use IO::File;
use IO::String;
use Path::Tiny;
use Carp;
use Encode qw(decode encode);
use Clone 'clone';
use Exporter qw/import/;

our @EXPORT = qw/handle_file upload_temp_file remove_temp_file/;

=head1 METHODS

=head2 upload_temp_file(params->{file},$creator,$opts)

Given an upload file handle and a creator string this function will create a
temporary storage file for the upload. Returns a HASH document containing the
file details:

    {
        # Fields needed for managing the upload
        'tempid'       => 'LJCyFMzwjN',
        'file_name'    => 'find.gif',

        # Metadata fields that can be overwritten by the user
        'access_level' => 'open_access',
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

Or on error a HASH document with the error message:

    {
        success       => 0,
        error_message => "Oops! Uploading $file_name failed."
    }

=cut

sub upload_temp_file {
    my ($file, $creator, $opts) = @_;

    h->log->debug("new upload by: $creator");

    unless ($file && $creator) {
        return {
            success       => 0,
            error_message => 'Sorry! The file upload failed.'
        };
    }

    # Gather all file metadata...
    my $now          = timestamp;
    my $tempid       = Data::Uniqid::uniqid;
    my $temp_file    = $file->{tempname};
    my $file_name    = $file->{filename};
    my $file_size    = int($file->{size});
    my $content_type = $file->{headers}->{"Content-Type"};
    my $rac_email    = $file->{rac_email} // '';

    h->log->info(
        "upload: $file_name ($content_type: $file_size bytes) by $creator");

    my $file_data = {
        file_name    => $file_name,
        file_size    => $file_size,
        tempid       => $tempid,
        content_type => $content_type,
        access_level => h->config->{default_access_level} // "open_access",
        relation     => "main_file",
        creator      => $creator,
        date_updated => $now,
        date_created => $now,
    };

    $file_data->{rac_email} = $rac_email if $rac_email;

    # Creating a new temporary storage for the upload files...
    h->log->info("creating temp container $tempid for $file_name");

    eval {
        my $store = h->get_temp_store();

        $store->index->add({ _id => $tempid });

        my $index = $store->index->files($tempid);

        unless ($index) {
            h->log->fatal("failed to create temp container $tempid!");
            return {
                success       => 0,
                error_message => "Oops! Uploading $file_name failed."
            };
        }

        h->log->info("copy $temp_file to temp container $tempid");

        $index->upload(IO::File->new("<$temp_file"),$file_name);

        unless ($index->get($file_name)) {
            h->log->fatal("failed to file $file_name in temp container $tempid!");
            return {
                success       => 0,
                error_message => "Oops! Uploading $file_name failed."
            };
        }

        # Store a copy of the file metadata next to the upload file...
        my $config_file = "$file_name.json";

        h->log->info("storing file metadata to $config_file");

        # Add some contextual data to the file metadata which shouldn't be
        # stored in the database...
        my $request_file_data = {
            %$file_data ,
            request => $opts
        };

        my $json = Catmandu->export_to_string($request_file_data, 'JSON',line_delimited=>1);

        h->log->debug("storing: $json");

        # Use the low level `add` method to be able to upload text as files...
        $index->add({_id => $config_file, _stream => $json});

        unless ($index->get($config_file)) {
            return {
                success       => 0,
                error_message => "Oops! Uploading $file_name failed."
            };
        }

        h->log->debug("deleting $temp_file");
        unlink $temp_file;

        $file_data->{success} = 1;
    };

    if ($@) {
        h->log->fatal("failed uploading $file_name in temp container $tempid!");
        h->log->fatal($@);
        return {
            success       => 0,
            error_message => "Oops! Uploading $file_name failed."
        };
    }

    return $file_data;
}

=head2 remove_temp_file($tempid, $creator, $opts)

Removes a temporary file upload when available on the file system. Returns
a HASH on success and error:

    { success => 1 }

=cut
sub remove_temp_file {
    my ($tempid, $creator, $opts) = @_;

    h->log->debug("request removing temp container $tempid by $creator");

    eval {
        my $store = h->get_temp_store();

        my $index = $store->index->files($tempid);

        if ($index) {
            h->log->info("removing temp container $tempid as requested by $creator");
            $store->index->delete($tempid);
            return { success => 1 };
        }
        else {
            h->log->debug("no such temp container $tempid");
            return { success => 0 };
        }
    };

    if ($@) {
        h->log->fatal("removing temp container $tempid by $creator failed!");
        h->log->fatal($@);
        return { success => 0 };
    }

    return { success => 1 };
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

    h->log->debug("updating file metadata for record $key");

    my $prev_pub = publication->get($key);

    # Delete files that are not needed
    for my $fi (_find_deleted_files($prev_pub, $pub)) {
        h->log->debug("deleted " . $fi->{file_name});
        _remove_file($key, $fi->{file_name});
        _remove_thumbnail($key, $fi->{file_name});
    }

    my $count = 0;

    my $temp_dir = [];

    for my $fi (@{$pub->{file}}) {

        # Generate a new file_id if not one existed
        $fi->{file_id} = publication->generate_id
            unless defined($fi->{file_id}) && length($fi->{file_id});

        h->log->debug("processing file-id: " . $fi->{file_id});

        # If we have a tempid, then there is a file upload waiting...
        if ($fi->{tempid} && $fi->{tempid} =~ /^\S+/) {
            my $tempid   = $fi->{tempid};
            my $filename = $fi->{file_name};

            # Record the temporary directory to be deleted
            push @$temp_dir , $fi->{tempid};

            h->log->debug("new upload with $tempid $filename -> $key");
            # TODO: Need to check the success of this step
            _make_file($key, $filename, $tempid);

            h->log->debug(
                "retrieving and updating technical metadata from cache");
            _update_tech_metadata($fi, $filename, $tempid);

            h->log->debug(
                "retrieve the checksum from the filestore or calculate it " .
                "on the fly"
            );
            _update_checksum($key,$fi,$filename);
        }

        # Update the stored metadata fields with the new ones
        # And, check if the first file changed...
        my $has_first_changed = 0;
        if ($prev_pub) {
            my ($prev_fi)
                = grep {$_->{file_id} eq $fi->{file_id}} @{$prev_pub->{file}};

            if (_is_file_metadata_changed($fi, $prev_fi)) {
                _update_file_metadata($fi, $prev_fi);
            }

            # Check if a new file has been reordered to the first one
            if (   $count == 0
                && $pub->{file}->[0]
                && $prev_pub->{file}->[0]
                && $pub->{file}->[0]->{file_id} ne
                $prev_pub->{file}->[0]->{file_id})
            {
                $has_first_changed = 1;
            }
            # Check if there wasn't any file and this is the first one
            elsif (
                   $count == 0
                   && $pub->{file}->[0]
                   && ! $prev_pub->{file}->[0]
            )
            {
                $has_first_changed = 1;
            }
            else {
                # this file didn't go to first positio or isn't a new
                # file in first postition
            }
        }
        else {
            # A new publication with files..
            $has_first_changed = 1 if $count == 0;
        }

        # Regenerate the first thumbnail...
        if ($has_first_changed) {
            h->log->info("regenerating thumbmail for $key " .  $fi->{file_name});
            _make_thumbnail($key, $fi->{file_name});
        }
        else {
            h->log->info("no thumbmail needed for $key " .  $fi->{file_name});
        }

        delete $fi->{tempid} if $fi->{tempid};

        if (h->config->{filestore}->{temp}->{options}->{autocleanup}) {
            for my $tempid (@$temp_dir) {
                h->log->debug("removing the temp-id uploads -> $tempid");
                h->get_temp_store->index->delete($tempid);
            }
        }

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

    my $pkg = Catmandu::Util::require_package($file_store,
        'Catmandu::Store::File');

    my $store = $pkg->new(%$file_opt);

    h->log->info("loading container $key");

    unless ($store->index->exists($key)) {
        h->log->error("container $key not found");
        return undef;
    }

    h->log->info("searching $filename in container $key");

    my $files = $store->index->files($key);

    my $res = $files->get($filename);

    unless ($res) {
        h->log->error("file $filename not found in container $key");
        return undef;
    }

    $file->{file_size}    = int($res->{size});
    $file->{content_type} = $res->{content_type};
    $file->{date_created} = timestamp($res->{created});
    $file->{date_updated} = timestamp($res->{modified});
    $file->{checksum}     = $res->{md5} if ($res->{md5});
    $file->{creator} //= 'system';
    $file->{file_id} //= publication->generate_id;

    $file->{access_level} //= 'open_access';
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
    my ($key, $filename, $tempid) = @_;

    h->log->info("moving $tempid `$filename` to filestore for record $key");

    my $uploader_package = h->config->{filestore}->{uploader}->{package};
    my $uploader_options = h->config->{filestore}->{uploader}->{options};

    my $pkg    = Catmandu::Util::require_package($uploader_package);
    my $worker = $pkg->new(%$uploader_options);

    $worker->work({key => $key, filename => $filename, tempid => $tempid});
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

sub _update_tech_metadata {
    my ($fi, $filename, $tempid) = @_;

    h->log->info("updating the technical metadata for $filename in temp container $tempid");

    my $files = h->get_temp_store->index->files($tempid);

    unless ($files) {
        h->log->error("no temp config file for temp if $tempid");
        return undef;
    }

    my $json = $files->as_string($files->get("$filename.json"));

    unless ($json) {
        h->log->error("no cached config file $filename.json found!");
        return undef;
    }

    my $data = Catmandu->import_from_string($json,'JSON');

    $data = $data->[0] if $data && ref($data) eq 'ARRAY';

    unless ($data) {
        h->log->error("failed to parse $filename.json from temp container $tempid to data!");
        return undef;
    }

    my $administrative_fields
        = h->config->{forms}->{dropzone_fields}->{administrative} // [];

    for my $name (@$administrative_fields) {
        my $value = $data->{$name};
        h->log->debug("setting $name = "
                . ($value ? $value : 'null')
                . " for $filename");
        $fi->{$name} = $value if $value;
    }

    return 1;
}

sub _update_checksum {
    my ($key, $fi, $filename) = @_;

    my $file_store = h->config->{filestore}->{default}->{package};
    my $file_opt   = h->config->{filestore}->{default}->{options};

    my $pkg = Catmandu::Util::require_package($file_store,
        'Catmandu::Store::File');

    my $store = $pkg->new(%$file_opt);

    h->log->info("loading container $key");

    unless ($store->index->exists($key)) {
        h->log->error("container $key not found");
        return undef;
    }

    h->log->info("searching $filename in container $key");

    my $files = $store->index->files($key);

    my $res = $files->get($filename);

    unless ($res) {
        h->log->error("no $filename in container $key");
        return undef;
    }

    # If we have a checksum, copy it from the file store
    my $checksum = $res->{md5};

    # Otherwise, try to calculate a dynamic checksum if the store supports it...
    if ($checksum) {
        h->log->info("$filename has checksum $checksum");
    }
    elsif (! $checksum && $files->can('checksum')) {
        $checksum= $files->checksum($filename);
        h->log->info("$filename has checksum $checksum");
    }
    else {
        h->log->info("$file_store has no checksum mechanism installed");
    }

    if ($checksum) {
        $fi->{checksum} = $checksum;
    }

    return 1;
}

sub _update_file_metadata {
    my ($fi, $prev_fi) = @_;

    h->log->debug("updating the file metadata");

    return unless $fi;
    return unless $prev_fi;

    my $administrative_fields
        = h->config->{forms}->{dropzone_fields}->{administrative} // [];
    my $descriptive_fields
        = h->config->{forms}->{dropzone_fields}->{descriptive} // [];

    # Throw away the unimportant stuff
    for my $name (keys %$fi) {
        if (grep(/^$name$/, @$administrative_fields)) {
            # keep these, do nothing
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
    for my $name (@$administrative_fields) {
        $fi->{$name} = $prev_fi->{$name};
    }

    $fi->{date_created} = timestamp unless $fi->{date_created};
    $fi->{date_updated} = timestamp;
}

# Return true when a input file is new or has changed descriptive metadata
# fields.
# usage: _is_file_metadata_changed($file_item, $previous_file_time)
sub _is_file_metadata_changed {
    my ($fi, $prev_fi) = @_;
    my $is_updated;

    my $descriptive_fields
        = h->config->{forms}->{dropzone_fields}->{descriptive} // [];

    for my $name (@$descriptive_fields) {
        if (!exists $fi->{$name} && !exists $prev_fi->{$name}) {
            # nothing changed...
        }
        elsif (defined($fi->{$name})
            && defined($prev_fi->{$name})
            && $fi->{$name} eq $prev_fi->{$name}) {
            # nothing changed...
        }
        else {
            $is_updated = 1;
        }
    }

    return $is_updated;
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
