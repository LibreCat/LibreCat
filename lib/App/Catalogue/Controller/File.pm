package App::Catalogue::Controller::File;

use Catmandu::Sane;
use Catmandu::Util;
use App::Helper;
use Dancer::FileUtils qw/path dirname/;
use Encode qw(decode encode);
use JSON::MaybeXS qw(decode_json encode_json);
use Exporter qw/import/;

our @EXPORT = qw/make_thumbnail delete_file update_file handle_file/;

sub make_thumbnail {
    my ($key, $filename) = @_;

    my $thumbnailer_package
        = h->config->{filestore}->{accesss_thumbnailer}->{package};
    my $thumbnailer_options
        = h->config->{filestore}->{accesss_thumbnailer}->{options};

    my $pkg    = Catmandu::Util::require_package($thumbnailer_package);
    my $worker = $pkg->new(%$thumbnailer_options);

    $worker->work({key => $key, filename => $filename});
}

sub update_file {
    my ($key, $filename, $path) = @_;

    my $uploader_package = h->config->{filestore}->{uploader}->{package};
    my $uploader_options = h->config->{filestore}->{uploader}->{options};

    my $pkg    = Catmandu::Util::require_package($uploader_package);
    my $worker = $pkg->new(%$uploader_options);

    $worker->work({key => $key, filename => $filename, path => $path,});
}

sub delete_file {
    my ($key, $filename) = @_;

    my $uploader_package = h->config->{filestore}->{uploader}->{package};
    my $uploader_options = h->config->{filestore}->{uploader}->{options};

    my $pkg    = Catmandu::Util::require_package($uploader_package);
    my $worker = $pkg->new(%$uploader_options);

    $worker->work({key => $key, filename => $filename, delete => 1});
}

sub handle_file {
    my $pub = shift;
    my $key = $pub->{_id};

    $pub->{file} = [$pub->{file}] if ref $pub->{file} ne "ARRAY";
    $pub->{file_order} = [$pub->{file_order}]
        if ref $pub->{file_order} ne "ARRAY";

    my $previous_pub = h->publication->get($key);

    if (!$previous_pub) {
        foreach my $fi (@{$pub->{file}}) {
            $fi = encode("utf8", $fi);
            $fi = decode_json($fi);
            $fi->{file_id} = h->new_record('publication') if !$fi->{file_id};

            my ($index)
                = grep {$pub->{file_order}->[$_] eq $fi->{tempid}}
                0 .. $#{$pub->{file_order}};

            if (defined $index) {
                $pub->{file_order}->[$index] = $fi->{file_id};
            }
            else {
                push @{$pub->{file_order}}, $fi->{file_id};
            }

            my $filename = $fi->{file_name};
            my $path = path(h->config->{tmp_dir}, $fi->{tempid}, $filename);

            update_file($key, $filename, $path);

            $fi->{open_access} = $fi->{access_level} eq "open_access" ? 1 : 0;

            delete $fi->{tempid}        if $fi->{tempid};
            delete $fi->{tempname}      if $fi->{tempname};
            delete $fi->{old_file_name} if $fi->{old_file_name};
            delete $fi->{file_json}     if $fi->{file_json};
        }
    }
    else {
        foreach my $fi (@{$pub->{file}}) {

            if (ref $fi ne "HASH") {
                $fi = encode("utf8", $fi);
                $fi = decode_json($fi);
            }

            # update of existing file
            if ($fi->{file_id}) {
                $fi->{date_updated} = h->now();

                #get index of $fi in $previous_pub->{file}

                my ($index) = grep {
                    $previous_pub->{file}->[$_]->{file_id} eq $fi->{file_id}
                } 0 .. $#{$previous_pub->{file}};

                if (defined $index and $fi->{tempid}) {
                    my $previous_file = $previous_pub->{file}->[$index];

                    # delete previous file
                    my $old_name = $previous_file->{file_name};
                    delete_file($key, $old_name);

                    # upload the new file
                    my $new_name = $fi->{file_name};
                    my $path     = path(h->config->{tmp_dir},
                        $fi->{tempid}, $fi->{file_name});
                    update_file($key, $new_name, $path);

                    $fi->{open_access}
                        = $fi->{access_level} eq "open_access" ? 1 : 0;

                    delete $fi->{tempid}        if $fi->{tempid};
                    delete $fi->{tempname}      if $fi->{tempname};
                    delete $fi->{old_file_name} if $fi->{old_file_name};
                    delete $fi->{file_json}     if $fi->{file_json};
                }
                else {
                    # looks like it wasn't an existing file after all
                    # can this even happen???
                    #$fi->{file_json} = encode_json($fi);
                }
            }

            #new file
            else {
                $fi->{file_id} = h->new_record('publication');
                my $now = h->now();
                $fi->{date_created} = $now;
                $fi->{date_updated} = $now;

                my ($index)
                    = grep {$pub->{file_order}->[$_] eq $fi->{tempid}}
                    0 .. $#{$pub->{file_order}};
                if (defined $index) {
                    $pub->{file_order}->[$index] = $fi->{file_id};
                }
                else {
                    push @{$pub->{file_order}}, $fi->{file_id};
                }

                my $filename = $fi->{file_name};
                my $path     = path(h->config->{tmp_dir},
                    $fi->{tempid}, $fi->{file_name});
                update_file($key, $filename, $path);

                $fi->{open_access}
                    = $fi->{access_level} eq "open_access" ? 1 : 0;

                delete $fi->{tempid}        if $fi->{tempid};
                delete $fi->{tempname}      if $fi->{tempname};
                delete $fi->{old_file_name} if $fi->{old_file_name};
                delete $fi->{file_json}     if $fi->{file_json};
            }
        }

# and then delete all files no longer in the list of files for that record
# (deleting files only removes the corresponding hidden input fields but not the actual files)
# (this makes it possible to discard all changes to a record, including changes to files)
#       foreach my $fil (@{$previous_pub->{file}}){
#           my( $index )= grep { $pub->{file}->[$_]->{file_id} eq $fil->{file_id} } 0..$#{$pub->{file}};
#           if(!defined $index){
#               delete_file($pub->{_id}, $fil->{file_name});
#           }
#       }
    }

    foreach my $fi (@{$pub->{file}}) {
        my ($index)
            = grep {$pub->{file_order}->[$_] eq $fi->{file_id}}
            0 .. $#{$pub->{file_order}};
        if (defined $index) {
            $fi->{file_order} = sprintf("%03d", $index);
        }
        else {
            $fi->{file_order} = sprintf("%03d", $#{$pub->{file_order}});
        }
    }

    return $pub->{file};
}

1;
