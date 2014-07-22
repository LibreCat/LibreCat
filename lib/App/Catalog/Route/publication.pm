package App::Catalog::Route::publication;

use App::Catalog::Helper;
use App::Catalog::Controller::Publication;
use Dancer ':syntax';
use Dancer::FileUtils qw/path/;
use Carp;
#use JSON;

prefix '/record' => sub {

	get '/new' => sub {
		my $type = params->{type} ||= '';
		
		if($type){
			my $id = new_publication();
			my $user = h->getPerson(session->{personNumber});
			template "backend/forms/$type", {id => $id, department => $user->{department}};
		}
		else {
			template 'add_new';
		}
	};

	# show the record, has user permission to see it?
	get '/edit/:id' => sub {
		my $id = param 'id';
	
		my $record = edit_publication($id);
		if($record){
			$record->{id} = $record->{_id} if $record->{_id} and !$record->{id};
			my $type = $record->{type};
			my $tmpl = "backend/forms/$type";
			template $tmpl, $record;
		}
	};

	post '/update' => sub {
		my $params = params;
		
		if(($params->{department} and $params->{department} eq "") or !$params->{department}){
			$params->{department} = ();
			if(session->{role} ne "superAdmin"){
				my $person = h->getPerson(session->{personNumber});
				foreach my $dep (@{$person->{department}}){
					push @{$params->{department}}, $dep->{id};
				}
			}
		}
		elsif($params->{department} and $params->{department} ne "" and ref $params->{department} ne "ARRAY"){
			$params->{department} = [$params->{department}];
		}
		
		if($params->{department}){
			my $deparray;
			foreach my $dept (@{$params->{department}}){
				my $authdep = h->getDepartment($dept);
				push @{$deparray}, {id => $authdep->{_id}, name => $authdep->{name}};
			}
			
			$params->{department} = ();
			$params->{department} = $deparray;
		}
		
		
		# my $author;
		# my $test;
		# if(ref $params->{author} ne "ARRAY"){
		# 	push @$author, $params->{author};
		# }
		# else{
		# 	$author = $params->{author};
		# }
		# foreach(@{$author}){
		# 	push @$test, from_json($_);
		# }
		# $params->{author} = $test;
		# #return to_dumper $params;
		#if($params->{finalSubmit} and $params->{finalSubmit} eq "recPublish"){
		#	$params->{status} = "public";
		#}
		my $result = update_publication($params);
		#return to_dumper $result;
		
		redirect '/myPUB';
	};

	get '/return/:id' => sub {
		my $id = params->{id};
		my $rec = h->publication->get($id);
		$rec->{status} = "returned";
		try {
			update_publication($rec);
			} catch {
				template "error", {error => "something went wrong"};
			}
		redirect '/myPUB';
	};

	# deleting records, for admins only
	get '/delete/:id' => sub {
		my $id = params->{id};
		
		delete_publication($id);
		redirect '/myPUB';
	};

};

get '/upload' => sub {
	template "backend/upload.tt";
};

post '/upload' => sub {
	my $file = request->upload('file');
	my $id = params->{recordId};
	my $file_id = new_publication();
	my $path = path(h->config->{upload_dir}, "$id", $file->{filename});
	my $dir = h->config->{upload_dir}."/".$id;
	mkdir $dir unless -e $dir;
	my $success = $file->copy_to($path);
	#return to_dumper $success;
	my $return;
	if($success){
		$return->{success} = 1;
		$return->{file_name} = $file->{filename};
		$return->{creator} = session->{user};
		$return->{file_size} = $file->{size};
		$return->{file_id} = $file_id;
		$return->{date_updated} = "2014-07-20T12:00";#???
		$return->{access_level} = "openAccess";
		$return->{content_type} = $file->{headers}->{"Content-Type"};
		$return->{relation} = "main_file";
		#$return->{error} = "this is not an error. Y U no display file?";
		$return->{file_json} = '{"file_name": "'.$return->{file_name}.'", ';
		$return->{file_json} .= '"file_id": "'.$return->{file_id}.'", ';
		$return->{file_json} .= '"content_type": "'.$return->{content_type}.'", ';
		$return->{file_json} .= '"access_level": "'.$return->{access_level}.'", ';
		$return->{file_json} .= '"date_updated": "'.$return->{date_updated}.'", ';
		$return->{file_json} .= '"date_created": "'.$return->{date_updated}.'", ';
		$return->{file_json} .= '"checksum": "ToDo", "file_size": "'.$return->{file_size}.'", ';
		$return->{file_json} .= '"relation": "main_file", ';
		$return->{file_json} .= '"language": "eng", "creator": "'.$return->{creator}.'", "open_access": "1", "year_last_uploaded": "2014"}';
	}
	else {
		$return->{success} = 0;
		$return->{error} = "There was an error while uploading your file."
	}
	#my $json = new JSON;
	my $return_json = to_json($return);
	return $return_json;
};

post '/upload/update' => sub {
	my $file = request->upload('file');
	my $old_file_name = params->{old_file_name};
	my $id = params->{id};
	my $file_id = params->{file_id};
	my $success = 1;
	
	if($file){
		# first delete old file from dir
		my $deldir = h->config->{upload_dir} ."/$id/$old_file_name";
		my $status = unlink "$deldir" if -e $deldir;
		#return to_dumper $status;
		
		# then copy new file to dir
		my $path = path(h->config->{upload_dir}, "$id", $file->{filename});
		my $dir = h->config->{upload_dir}."/".$id;
		mkdir $dir unless -e $dir;
		$success = $file->copy_to($path);
	}
    
    # then return data of updated file
	my $return;
	if($success){
		$return->{success} = 1;
		$return->{file_name} = $file ? $file->{filename} : $old_file_name;
		$return->{creator} = session->{user};
		$return->{file_size} = $file ? $file->{size} : "";
		$return->{file_id} = $file_id;
		$return->{date_updated} = "2014-07-01T12:00";#???
		$return->{access_level} = params->{access_level} ? params->{access_level} : "openAccess";
		$return->{open_access} = (params->{access_level} and params->{access_level} eq "openAccess") ? 1 : 0;
		$return->{embargo} = params->{embargo} ? params->{embargo} : "";
		$return->{content_type} = $file ? $file->{headers}->{"Content-Type"} : "";
		$return->{checksum} = "ToDo";
		$return->{file_title} = params->{file_title} if params->{file_title};
		$return->{description} = params->{description} if params->{description};
		#$return->{error} = "this is not an error. Y U no display file?";
		$return->{old_file_name} = $old_file_name;
		$return->{relation} = params->{relation} ? params->{relation} : "main_file";
		
		my $record = h->publication->get($id);
		foreach my $recfile (@{$record->{file}}){
			if($recfile->{file_id} eq $return->{file_id}){
				$return->{year_last_uploaded} = $recfile->{year_last_uploaded};
				$return->{file_size} = $recfile->{file_size} if $return->{file_size} eq "";
				$return->{content_type} = ($return->{content_type} eq "" and $recfile->{content_type}) ? $recfile->{content_type} : "";
				$return->{date_created} = $recfile->{date_created};
				if($return->{access_level} eq "openAccess"){
					$return->{open_access} = 1;
					$return->{embargo} = "";
				}
				else {
					$return->{open_access} = 0;
				}
				
				$recfile = ();
				$recfile = $return;
				delete $recfile->{file_json};
				delete $recfile->{success};
				delete $recfile->{old_file_name};
			}
		}
		
		$return->{file_json} = '{"file_name": "'.$return->{file_name}.'", ';
		$return->{file_json} .= '"file_id": "'.$return->{file_id}.'", ';
		$return->{file_json} .= '"title": "'.$return->{file_title}.'", ' if $return->{file_title};
		$return->{file_json} .= '"description": "'.$return->{description}.'", ' if $return->{description};
		$return->{file_json} .= '"content_type": "'.$return->{content_type}.'", ';
		$return->{file_json} .= '"access_level": "'.$return->{access_level}.'", ';
		$return->{file_json} .= '"embargo": "'.$return->{embargo}.'", ' if ($return->{embargo} and $return->{embargo} ne "");
		$return->{file_json} .= '"date_updated": "'.$return->{date_updated}.'", ';
		$return->{file_json} .= '"date_created": "'.$return->{date_updated}.'", ';
		$return->{file_json} .= '"checksum": "ToDo", "file_size": "'.$return->{file_size}.'", ';
		$return->{file_json} .= '"language": "eng", "creator": "'.$return->{creator}.'", ';
		$return->{file_json} .= '"open_access": "'.$return->{open_access}.'", ';
		$return->{file_json} .= '"relation": "'.$return->{relation}.'", ';
		$return->{file_json} .= '"year_last_uploaded": "2014"}';
		
		h->publication->add($record);
		h->publication->commit;
	}
	else {
		$return->{success} = 0;
		$return->{error} = "There was an error while uploading your file."
	}
	#my $json = new JSON;
	my $return_json = to_json($return);
	return $return_json;
};

post '/upload/delete' => sub {
	my $recordid = params->{id};
	my $filename = params->{filename};
	my $dir = h->config->{upload_dir} ."/$recordid/$filename";
    my $status = rmdir $dir if -e $dir || 0;
    croak "Error: could not delete files" if $status;
};

1;
