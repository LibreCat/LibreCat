package App::Catalogue::Controller::File;

use Catmandu::Sane;
use Catmandu::Util;
use App::Helper;
use Dancer::FileUtils qw/path dirname/;
use Dancer ':syntax';
use File::Copy;
use Carp;
use Encode qw(decode encode);
use JSON::MaybeXS qw(decode_json encode_json);
use Exporter qw/import/;

our @EXPORT = qw/make_thumbnail delete_file update_file handle_file upload_temp_file/;

=head2 upload_temp_file(params->{file},$creator)

Given an upload file handle and a creator string this function will create a 
temporary storage file for the upload. Returns a JSON document containing the
file details:

    {
        'access_level' => 'open_access',
        'content_type' => 'image/gif',
        'creator'      => 'einstein',
        'date_created' => '2016-05-31T11:05:22Z',
        'date_updated' => '2016-05-31T11:05:22Z',
        'file_name'    => 'find.gif',
        'file_size'    => '66658',
        'open_access'  => 1,
        'relation'     => 'main_file',
        'success'      => 1,
        'tempid'       => 'LJCyFMzwjN',
        'tempname'     => '/tmp/LJCyFMzwjN.gif'
    }

=cut
sub upload_temp_file {
    my ($file,$creator) = @_;

    unless ($file) {
        return {
            success => 0, 
            error_message => 'Sorry! The file upload failed.'
        } 
    };

    my $now = h->now;
    my $tempid = $file->{tempname};
    
    $tempid =~ s/.*\/([^\/\.]*)\.*.*/$1/g;
    
    my $file_data = {
        file_name          => $file->{filename},
        file_size          => $file->{size},
        tempname           => $file->{tempname},
        tempid             => $tempid,
        content_type       => $file->{headers}->{"Content-Type"},
        access_level       => "open_access",
        open_access        => 1,
        relation           => "main_file",
        creator            => $creator,
        date_updated       => $now,
        date_created       => $now,
    };

    my $filedir   = path(h->config->{filestore}->{tmp_dir}, $tempid);
    mkdir $filedir || croak "Could not create dir $filedir: $!";
    
    my $filepath  = path(h->config->{filestore}->{tmp_dir}, $tempid, $file->{filename});
    copy($file->{tempname}, $filepath);

    unlink $file->{tempname};
 
    # Required for showing a success upload in the web interface
    $file_data->{success} = 1 if (-r $filepath);

    return $file_data;
}

=head2 make_thumbnail($key,$filename)

Generate a thumbnail for the publication $key with filename $filename.

=cut
sub make_thumbnail {
    my ($key,$filename) = @_;

    my $thumbnailer_package = h->config->{filestore}->{accesss_thumbnailer}->{package};
    my $thumbnailer_options = h->config->{filestore}->{accesss_thumbnailer}->{options};

    my $pkg = Catmandu::Util::require_package($thumbnailer_package);
    my $worker = $pkg->new(%$thumbnailer_options);

    $worker->work({
        key      => $key,
        filename => $filename
    });
}

=head2 update_file($key,$filename,$path)

Import for publication $key a file with name $filename as found in the path $path

=cut
sub update_file {
    my ($key,$filename,$path) = @_;

    my $uploader_package = h->config->{filestore}->{uploader}->{package};
    my $uploader_options = h->config->{filestore}->{uploader}->{options};

    my $pkg = Catmandu::Util::require_package($uploader_package);
    my $worker = $pkg->new(%$uploader_options);

    $worker->work({
        key      => $key, 
        filename => $filename, 
        path     => $path,
    });
}


=head2 delete_file($key,$filename)

Delete for publication $key the file $filename from permanent storage

=cut
sub delete_file {
    my ($key,$filename) = @_;

    my $uploader_package = h->config->{filestore}->{uploader}->{package};
    my $uploader_options = h->config->{filestore}->{uploader}->{options};

    my $pkg = Catmandu::Util::require_package($uploader_package);
    my $worker = $pkg->new(%$uploader_options);

    $worker->work({
        key      => $key, 
        filename => $filename, 
        delete   => 1
    });
}

=head2 handle_file($pub)

For the given publication HASH update the file section (upload files, reorder files) 
when required. Return an update publication HASH with the file changes in place.

=cut
sub handle_file {
    my $pub = shift;
    my $key = $pub->{_id};

    $pub->{file}       = _decode_file($pub->{file});
    $pub->{file_order} = _decode_fileorder($pub->{file_order});

    my $prev_pub = h->publication->get($key);

    for my $fi (@{$pub->{file}}) {
        # Generate a new file_id if not one existed
        $fi->{file_id} = h->new_record('publication') if ! $fi->{file_id};

        # If we have a tempid, then there is a file upload waiting...
        if ($fi->{tempid}) {
            my $filename = $fi->{file_name};
            my $path     = path(h->config->{filestore}->{tmp_dir}, $fi->{tempid}, $filename);
            
            update_file($key,$filename,$path);

            # Calculate the new file order
            _update_fileorder($pub, $fi->{tempid}, $fi->{file_id});
        }

        # Update the stored metadata fields with the new ones
        _update_keys($fi,$prev_pub);

        delete $fi->{tempid}        if $fi->{tempid};
        delete $fi->{tempname}      if $fi->{tempname};
    }

    # Recalculate the file order
    foreach my $fi (@{$pub->{file}}){
        my( $index )= grep { $pub->{file_order}->[$_] eq $fi->{file_id} } 0..$#{$pub->{file_order}};
        if(defined $index){
            $fi->{file_order} = sprintf("%03d", $index);
        }
        else {
            $fi->{file_order} = sprintf("%03d", $#{$pub->{file_order}});
        }
    }

    return $pub->{file};
}

sub _decode_file {
    my $file = shift;
    $file = [$file] unless ref $file eq 'ARRAY';
    for my $fi (@$file) {
        if (ref $fi ne 'HASH') {
            $fi = encode("utf8", $fi);
            $fi = decode_json($fi);
        }
    }
    $file;
}

sub _decode_fileorder {
    my $file_order = shift;
    $file_order = [$file_order] unless ref $file_order eq 'ARRAY'; 
    $file_order;
}

sub _update_fileorder {
    my ($pub,$tempid,$file_id) = @_;

    my ($index) = grep { $pub->{file_order}->[$_] eq $tempid } 0..$#{$pub->{file_order}};

    if(defined $index){
        $pub->{file_order}->[$index] = $file_id;
    }
    else {
        push @{$pub->{file_order}}, $file_id;
    }
}

sub _update_keys {
    my ($fi,$pub) = @_;

    return unless $fi;
    return unless $pub;

    my ($prev_fi) = grep { $_->{file_id} eq $fi->{file_id} } @{$pub->{file}};

    my @important_fields  = qw(
            file_id file_order file_name file_size content_type 
            creator date_created
            );

    my @changeable_fields = qw(
            title description access_level request_a_copy 
            open_access embargo relation
            );

    # Throw away the unimportant stuff
    for my $name (keys %$fi) {
        if (grep(/^$name$/,@important_fields)) {
            # do nothing
        }
        elsif (! grep(/^$name$/,@changeable_fields)) {
            delete $fi->{$name};
        }
        elsif (! defined $fi->{$name}) {
            delete $fi->{$name};
        }
    }

    # Keep important stuff that can be written only once
    if ($prev_fi) {
        for my $name (@important_fields) {
            $fi->{$name} = $prev_fi->{$name};
        }
    }

    $fi->{date_created} = h->now unless $fi->{date_created};

    $fi->{date_updated} = h->now;
}

1;
