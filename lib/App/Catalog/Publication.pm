package App::Catalog::Publication;

use App::Catalog::Helper;
use Dancer ':syntax';
#use JSON;

prefix '/record' => sub {

	get '/new' => sub {
		my $type = params->{type} ||= '';
		
		if($type){
			my $bag = h->bag->get('1');
			my $id = $bag->{"latest"};
			$id++;
			$bag = h->bag->add({_id=> "1", latest => $id});
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
		h->publications->delete($id);
		h->publications->commit;
		redirect '/myPUB/search';
	};

};

1;
