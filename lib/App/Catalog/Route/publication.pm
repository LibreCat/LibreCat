package App::Catalog::Route::publication;

use App::Catalog::Helper;
use App::Catalog::Controller::Publication;
use Dancer ':syntax';
use Dancer::FileUtils qw/path/;
#use JSON;

prefix '/record' => sub {

	get '/new' => sub {
		my $type = params->{type} ||= '';
		
		if($type){
			my $id = new_publication();
			template "backend/forms/$type", {id => $id};
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
		$return->{filename} = $file->{filename};
		$return->{user} = session->{user};
		$return->{size} = $file->{size};
		$return->{file_id} = $file_id;
		$return->{date} = "now";#???
		$return->{access} = "openAccess";
		$return->{content_type} = $file->{headers}->{"Content-Type"};
		#$return->{error} = "this is not an error. Y U no display file?";
		$return->{file_json} = '{"file_name": "'.$return->{filename}.'", "file_id": "'.$return->{file_id}.'", "content_type": "'.$return->{content_type}.'", "access_level": "'.$return->{access}.'", "date_updated": "'.$return->{date}.'", "date_created": "'.$return->{date}.'", "checksum": "ToDo", "file_size": "'.$return->{size}.'", "language": "eng", "creator": "'.$return->{user}.'", "open_access": "1", "year_last_uploaded": "2014"}';
	}
	else {
		$return->{success} = 0;
		$return->{error} = "There was an error while uploading your file."
	}
	#my $json = new JSON;
	my $return_json = to_json($return);
	return $return_json;
};

1;
