package App::Catalog::Route::publication;

use App::Catalog::Helper;
use App::Catalog::Controller::Publication;
use Dancer ':syntax';
use Dancer::FileUtils qw/path/;

prefix '/record' => sub {

	get '/new' => sub {
		my $type = params->{type} ||= '';
		
		if($type){
			my $id = new_publication();
			template "backend/forms/$type", {oId => $id};
		}
		else {
			template 'add_new';
		}
	};

	# show the record, has user permission to see it?
	get '/edit/:id' => sub {
		my $id = param 'id';
	
		my $record = h->publications->get($id);
		if($record){
			my $type = $record->{documentType};
			$record->{personNumber} = session->{personNumber};
			my $tmpl = "backend/forms/$type";
			template $tmpl, $record;
		}
	};

	post '/update' => sub {
		my $params = params;
		my $author;
		my $test;
		if(ref $params->{author} ne "ARRAY"){
			push @$author, $params->{author};
		}
		else{
			$author = $params->{author};
		}
		foreach(@{$author}){
			push @$test, from_json($_);
		}
		$params->{author} = $test;
		#return to_dumper $params;
		if($params->{finalSubmit} and $params->{finalSubmit} eq "recPublish"){
			$params->{submissionStatus} = "public";
		}
		my $result = h->update_publication($params);
		#return to_dumper $result;

		redirect '/myPUB';
	};

	get '/return/:id' => sub {
		my $id = params->{id};
		my $rec = h->publications->get($id);
		$rec->{submissionStatus} = "returned";
		h->update_publication($rec);

		redirect '/myPUB/search';
	};

	# deleting records, for admins only
	get '/delete/:id' => sub {
		my $id = params->{id};
		#
		redirect '/myPUB/search';
	};

};

#post '/upload' => sub {
#	my $file = request->upload('file_name');
#	my $path = path(h->config->{upload_dir}, "$id", "file_name");
#	$file->copy_to($path);
#};

1;
