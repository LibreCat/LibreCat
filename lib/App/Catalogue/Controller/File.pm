package App::Catalogue::Controller::File;

use Catmandu::Sane;
use Catmandu::Util qw(join_path segmented_path);
use App::Helper;
use Dancer::FileUtils qw/path dirname/;
use Carp;
use JSON;
use File::Copy;
use File::Path qw/rmtree/;
use File::Basename;
use Exporter qw/import/;

our @EXPORT = qw/update_file delete_file handle_file make_thumbnail/;

my $upload_dir = h->config->{upload_dir};
my $thumb_dir = h->config->{thumb_dir};

sub make_thumbnail {
    my ($id, $file_name) = @_;
    my $file_path = path(h->get_file_path($id), $file_name);
    my $thumbnail = path(dirname($file_path), "thumbnail.*");
    my $thumbnail_name = path(dirname($file_path), "thumbnail.png");
    unless (-e $thumbnail) {
        system "convert -resize x200 ${file_path}[0] $thumbnail_name";
    }
    if(-e $thumbnail_name){
    	return $thumbnail_name;
    }
}

sub handle_file {
	my $pub = shift;
	$pub->{file} = [$pub->{file}] if ref $pub->{file} ne "ARRAY";
	$pub->{file_order} = [$pub->{file_order}] if ref $pub->{file_order} ne "ARRAY";

	my $previous_pub = h->publication->get($pub->{_id});
	my $dest_dir = h->get_file_path($pub->{_id});

	if(!$previous_pub){
		foreach my $fi (@{$pub->{file}}){
			$fi = from_json($fi);
			$fi->{file_id} = h->new_record('publication') if !$fi->{file_id};
			my( $index )= grep { $pub->{file_order}->[$_] eq $fi->{tempid} } 0..$#{$pub->{file_order}};
			if(defined $index){
				$pub->{file_order}->[$index] = $fi->{file_id};
			}
			else {
				push @{$pub->{file_order}}, $fi->{file_id};
			}

			my $filepath = path(h->config->{tmp_dir}, $fi->{tempid}, $fi->{file_name});
			system "mkdir -p $dest_dir" unless -d $dest_dir;

			move($filepath,$dest_dir);

			# remove tmp-folder
			#my $path = path(h->config->{upload_dir}, $fi->{tempid});
			#system "rm -r $path" if -d $path;

			$fi->{open_access} = $fi->{access_level} eq "open_access" ? 1 : 0;

			delete $fi->{tempid} if $fi->{tempid};
			delete $fi->{tempname} if $fi->{tempname};
			delete $fi->{old_file_name} if $fi->{old_file_name};
			$fi->{file_json} = to_json($fi);
		}
	}
	else{
		foreach my $fi (@{$pub->{file}}){
			if(ref $fi eq "HASH" and $fi->{file_json}){
				$fi = $fi->{file_json};
			}
			$fi = from_json($fi);
			#update of existing file
			if($fi->{file_id}){
				$fi->{date_updated} = h->now();
				#get index of $fi in $previous_pub->{file}
				my $previous_file;
				my( $index )= grep { $previous_pub->{file}->[$_]->{file_id} eq $fi->{file_id} } 0..$#{$previous_pub->{file}};
				if(defined $index and $fi->{tempid}){
					$previous_file = $previous_pub->{file}->[$index];
					#unlink previous file
					my $file = "$dest_dir/$previous_file->{file_name}";
					unlink($file);
					#copy new file to previous file's folder
					my $filepath = path(h->config->{tmp_dir}, $fi->{tempid}, $fi->{file_name});
					move($filepath, $dest_dir);

					#my $path = path(h->config->{upload_dir}, $fi->{tempid});
					#system "rm -r $path" if -d $path;

					$fi->{open_access} = $fi->{access_level} eq "open_access" ? 1 : 0;

					delete $fi->{tempid} if $fi->{tempid};
					delete $fi->{tempname} if $fi->{tempname};
					delete $fi->{old_file_name} if $fi->{old_file_name};
					$fi->{file_json} = to_json($fi);
				}
				else {
					# looks like it wasn't an existing file after all
					# can this even happen???
					$fi->{file_json} = to_json($fi);
				}
			}
			#new file
			else {
				$fi->{file_id} = h->new_record('publication');
				my $now = h->now();
				$fi->{date_created} = $now;
				$fi->{date_updated} = $now;

				my( $index )= grep { $pub->{file_order}->[$_] eq $fi->{tempid} } 0..$#{$pub->{file_order}};
				if(defined $index){
					$pub->{file_order}->[$index] = $fi->{file_id};
				}
				else {
					push @{$pub->{file_order}}, $fi->{file_id};
				}

				system "mkdir -p $dest_dir" unless -d $dest_dir;
				my $filepath = path(h->config->{tmp_dir}, $fi->{tempid}, $fi->{file_name});
				move($filepath, $dest_dir);

				#my $path = path(h->config->{upload_dir}, $fi->{tempid});
				#system "rm -r $path" if -d $path;

				$fi->{open_access} = $fi->{access_level} eq "open_access" ? 1 : 0;

				delete $fi->{tempid} if $fi->{tempid};
				delete $fi->{tempname} if $fi->{tempname};
				delete $fi->{old_file_name} if $fi->{old_file_name};
				$fi->{file_json} = to_json($fi);
			}
		}

		# and then delete all files no longer in the list of files for that record
		# (deleting files only removes the corresponding hidden input fields but not the actual files)
		# (this makes it possible to discard all changes to a record, including changes to files)
		foreach my $fil (@{$previous_pub->{file}}){
			my( $index )= grep { $pub->{file}->[$_]->{file_id} eq $fil->{file_id} } 0..$#{$pub->{file}};
			if(!defined $index){
				delete_file($pub->{_id}, $fil->{file_name});
			}
		}
	}

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

sub delete_file {
	my $pub_id = shift;
    my $file_name = shift;
    my $dest_dir = h->get_file_path($pub_id);
    my $status;
    if($file_name){
    	my $file = path($dest_dir, $file_name);
    	$status = unlink($file);
    }
    else {
    	$status = rmtree [$dest_dir] if -e $dest_dir || 0;
    }
    return $status;
}

1;
