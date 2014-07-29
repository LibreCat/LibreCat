#!/usr/local/env perl

use lib qw (../lib);
use Dancer qw(:syntax);
use Catmandu::Fix qw(arxiv_mapping);
use Catmandu::Importer::ArXiv;
use Catmandu::Importer::Inspire;

get '/test' => sub {
	return request->uri;
};

get '/arxiv/:id' => sub {
	my $id = params->{id};
	#my $fixer = Catmandu::Fix->new(fixes => ["arxiv_mapping()"]);
	my $importer = Catmandu::Importer::ArXiv->new(query => $id, fix =>  ['arxiv_mapping()']);
	
	return to_yaml $importer->first;
};

get '/inspire/:id' => sub {
	my $id = params->{id};
	my $imp = Catmandu::Importer::Inspire->new(id => $id, fix => ['fixes/inspire_mapping.fix']);
	return to_yaml $imp->first;
};

dance;