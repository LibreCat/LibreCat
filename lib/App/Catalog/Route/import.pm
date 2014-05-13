package App::Catalog::Import;

use Dancer ':syntax';
use App::Catalog::Helper;


sub _process_import {
	my $id = shift;
	my $source = h->classifyId($id);
	
	_get_$source($id);
}

sub _get_arxiv {
	my $id = shift;
	my $importer = Catmandu::Importer::ArXiv->new(query => $id, fixes => ["arxiv_mapping()"]);
	return $importer->first;
}

sub _get_doi {
	my $id = shift;
	my $importer = Catmandu::Importer::DOI->new(doi => $id, fixes => ["doi_mapping()"]);
	return $importer->first;
}

sub _get_pubmed {
	my $id = shift;
	my $importer = Catmandu::Importer::Pubmed->new(term => $id, fixes => ["pubmed_mapping()"]);
	return $importer->first;
}

post '/import' => sub {
	my $params = params('body');
	my $id = params->{'id'};
	my $pub = _process_import($id);
	template "backend/forms/$pub->{type}", $pub;
};

# for admins only? otherwise: garbage collection in db
post '/import/bibtex/:bibtex' => sub {
	my $bibtex = params 'bibtex';
	my $importer = Catmandu->importer('bibtex');
};

1;
