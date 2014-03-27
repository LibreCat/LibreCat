package App::Catalog::Publication;

use App::Catalog::Helper;
use Dancer ':syntax';

prefix '/record' => sub {

	get '/new' => sub {
		my $type = params 'type';
		(!$type) && template 'add_new';
		template 'add_type';
	};

	# show the record, has user permission to see it?
	get '/edit/:id' => sub {
		my $id = params 'id';
	
		my $record = h->publications->get($id);
		if($record){
			my $type = $record->{documentType};
			$record->{personNumber} = "73476";
			$record->{xkeyword} = join('; ', @{$record->{keyword}});
			#my not needed here?
			#my $tmpl = "backend/forms/" . h->config->{forms}->{publicationTypes}->{lc($type)}->{tmpl} . ".tt";
			my $tmpl = "backend/forms/$type";
			template $tmpl, $record;
		}
	};

	post '/update' => sub {
		my $params = params;

		my $record = h->publications->get($params->{recordOId});

		# TODO: nice method for merging records 

		h->add_update_pub($record);

		forward '/';
	};

	get 'return/:id' => sub {
		my $id = params 'id';

		forward '/update', {_id => $id, submissionStatus => 'returned'};
	};

	get 'publish/:id' => sub {
		my $id = params 'id';

		forward '/update', {_id => $id, submissionStatus => 'public'};
	};

	# deleting records, for admins only
	del 'delete/:id' => sub {
		my $id = params 'id';
		h->bag->delete($id);
	};

};

1;
