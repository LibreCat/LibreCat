package App::Catalog::Controller::File;

use Catmandu::Sane;
use App::Catalog::Helper;
use Dancer::FileUtils qw/path dirname/;
use Carp;
use JSON;
use File::Copy;
use File::Path qw/rmtree/;
use Exporter qw/import/;

our @EXPORT = qw/new_file update_file delete_file handle_file/;

my $upload_dir = h->config->{upload_dir};

sub _create_id {
    my $bag = h->bag->get('1');
    my $id  = $bag->{"latest"};
    $id++;
    $bag = h->bag->add( { _id => "1", latest => $id } );
    return $id;
}

sub _bagit {
	my $path = shift;
	system "./bagit.py $path";
}

sub handle_file {
	my $pub = shift;
	$pub->{file} = [$pub->{file}] if ref $pub->{file} ne "ARRAY";
	$pub->{file_order} = [$pub->{file_order}] if ref $pub->{file_order} ne "ARRAY";
	my $previous_pub = h->publication->get($pub->{_id});
	
	if(!$previous_pub){
		foreach my $fi (@{$pub->{file}}){
			$fi = from_json($fi);
			$fi->{file_id} = new_file();
			my( $index )= grep { $pub->{file_order}->[$_] eq $fi->{tempid} } 0..$#{$pub->{file_order}};
			$pub->{file_order}->[$index] = $fi->{file_id};
			
			my $path = h->config->{upload_dir} . "/" . $pub->{_id};
			mkdir $path || croak "Could not create path $path: $!";
#			my $pathh = path(h->config->{upload_dir}, $pub->{_id}, $fi->{file_id});
#			mkdir $pathh || croak "Could not create pathh $pathh: $!";
			my $filepath = path(h->config->{upload_dir}, $fi->{file_name});
			my $newfilepath = path(h->config->{upload_dir}, $pub->{_id}, $fi->{file_name});
			move($filepath, $newfilepath);
			
			delete $fi->{tempid} if $fi->{tempid};
			delete $fi->{tempname} if $fi->{tempname};
			delete $fi->{old_file_name} if $fi->{old_file_name};
			$fi->{file_json} = to_json($fi);
		}
	}
	else{
		foreach my $fi (@{$pub->{file}}){
			$fi = from_json($fi);
			#update of existing file
			if($fi->{file_id}){
				$fi->{date_updated} = h->now();
				#get index of $fi in $previous_pub->{file}
				my( $index )= grep { $previous_pub->{file}->[$_]->{file_id} eq $fi->{file_id} } 0..$#{$previous_pub->{file}};
				my $previous_file = $previous_pub->{file}->[$index];
				#unlink previous file
				my $file = $upload_dir ."/$pub->{_id}/$previous_file->{file_name}";
				unlink($file);
				#copy new file to previous file's folder
				my $filepath = path(h->config->{upload_dir}, $fi->{file_name});
				my $newfilepath = path(h->config->{upload_dir}, $pub->{_id}, $fi->{file_name});
				move($filepath, $newfilepath);
				
				delete $fi->{tempid} if $fi->{tempid};
				delete $fi->{tempname} if $fi->{tempname};
				delete $fi->{old_file_name} if $fi->{old_file_name};
				$fi->{file_json} = to_json($fi);
			}
			#new file
			else {
				$fi->{file_id} = new_file();
				my $now = h->now();
				$fi->{date_created} = $now;
				$fi->{date_updated} = $now;
				
				my( $index )= grep { $pub->{file_order}->[$_] eq $fi->{tempid} } 0..$#{$pub->{file_order}};
				$pub->{file_order}->[$index] = $fi->{file_id};
				
				my $path = h->config->{upload_dir} . "/" . $pub->{_id};
				mkdir $path || croak "Could not create path $path: $!";
#				my $pathh = path(h->config->{upload_dir}, $pub->{_id}, $fi->{file_id});
#				mkdir $pathh || croak "Could not create pathh $pathh: $!";
				my $filepath = path(h->config->{upload_dir}, $fi->{file_name});
				my $newfilepath = path(h->config->{upload_dir}, $pub->{_id}, $fi->{file_name});
				move($filepath, $newfilepath);
				
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
			if(!$index){
				delete_file($pub->{_id}, $fil->{file_name});
			}
		}
	}
	
	return $pub->{file};
}

sub new_file {
    return _create_id;
}

sub check_request_a_copy {
	my $pub = shift;
	if($pub->{file}){
		my $raq = 0;
		foreach my $fi (@{$pub->{file}}){
			$raq = 1 if $fi->{request_a_copy};
		}
		$pub->{request_a_copy} = $raq;
	}
	elsif(!$pub->{file} and $pub->{request_a_copy}){
		delete $pub->{request_a_copy};
	}
}

# this sub should be called from the sub 'update_publication',
# if publication has a file attached
sub update_file {
	my $pub = shift;
	my $dir = $upload_dir ."/$pub->{_id}";
	mkdir $dir unless -e $dir || croak "Can't create directory";

}

# this sub should be called from the sub 'delete_publication',
# if publication has a file attached
sub delete_file {
	my $pub_id = shift;
    my $file_name = shift;
    my $status;
    if($file_name){
    	my $file = path(h->config->{upload_dir}, $pub_id, $file_name);
    	$status = unlink($file);
    }
    else {
    	my $dir = path(h->config->{upload_dir}, $pub_id);
    	$status = rmtree [$dir] if -e $dir || 0;
    }
    return $status;
}

1;
