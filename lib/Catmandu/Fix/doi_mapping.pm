package Catmandu::Fix::doi;

use Catmandu::Sane;

use Moo;

my %TYPE_MAP = (
	journal_article => 'journalArticle',
    conference_paper => 'conference',
    book_content => 'bookChapter',
    book_title => 'book',
    book_series => 'bookEditor',
);

sub fix {
	my ($self, $pub) = @_;

	$record->{status} = 'submitted';
    $record->{publicationStatus} = 'published';
    $record->{doi} = $doi;
    $record->{year} = &_cC($record->{publishingYear} = $data->{year}[0]);
    #$record->{message} = 'via CrossRef-Import at ' . $tm;
}

1;


__END__
   my %xRefTypeMapping = (
    		journal_article => 'journalArticle',
    		conference_paper => 'conference',
    		book_content => 'bookChapter',
    		book_title => 'book',
    		book_series => 'bookEditor'
    );
    
    # catch error: empty DOI
      if($web->{doi} eq '') {
	  $web->{errorMessagesDoi}  = [ {message => "No DOI entered."}];
	  return $self->printTemplate( 'endNoteImport', $web);
      }
    
    my @doiArray = split(/,/, $web->{doi});
    
    foreach (@doiArray) {
    	my $doi = $_;
    	my $doiSuperior;
    	$doi =~ s/^\s+|\s+$//g;
    	
    	if($doi =~ /.*\_\d/){
    		$doiSuperior = substr($doi,0,index($doi,"_"));
    	}
    	
    	  # Fetch
    	my $xRefUrl = 'http://www.crossref.org/openurl/?pid=publikationsdienste.ub@uni-bielefeld.de&id=doi:';
    	my $url = $xRefUrl . $doi . '&noredirect=true';
    	my $browser = LWP::UserAgent->new();
    	my $response = $browser->get($url);
    	my $urlSuperior; my $responseSuperior;
    	if($doiSuperior){
    		$urlSuperior = $xRefUrl . $doiSuperior . '&noredirect=true';
    		$responseSuperior = $browser->get($urlSuperior);
    	}
    	
    	  # Parse Response
    	my $xmlParser = new XML::Simple();
    	my $xml = $xmlParser->XMLin($response->content(), forcearray => ['contributor', 'issn', 'isbn', 'year']);
    	my $data = $xml->{'query_result'}->{body}->{query};
    	my $xmlSuperior; my $dataSuperior;
    	if($responseSuperior){
    		$xmlSuperior = $xmlParser->XMLin($responseSuperior->content(), forcearray => ['contributor']);
    		$dataSuperior = $xmlSuperior->{'query_result'}->{body}->{query};
    	}
    	
    	  # Error catching: doi not found
    	if ($data->{msg} && $data->{msg} =~ /doi not found/i) {
    		$web->{errorMessagesDoi}  = [ {message => "DOI not found in CrossRef"}];
    		return $self->printTemplate( 'endNoteImport', $web);
    	}
    	
    	
    	  ######################################
    	 ####### Start filling record hash ####
    	######################################
    	my $record = undef;
    	$record->{separator} = ';';
    	$record->{order} = 'lName';
    	$record->{partSeparator} = ',';
    	
    	  # Sth2do with authors editors and subjects (?)
    	foreach ( qw(au ed su) ) {
    		$record->{"${_}_order"} = $record->{order};
    		$record->{"${_}_partSeparator"} = $record->{partSeparator};
    	}
    	
    	  # fields independent of publication type
    	$record->{submissionStatus} = 'submitted';
    	$record->{publicationStatus} = 'published';
    	$record->{doi} = $doi;
    	$record->{publishingYear} = &_cC($record->{publishingYear} = $data->{year}[0]);
    	$record->{message} = 'via CrossRef-Import at ' . $tm;
    	
    	  # isbn
    	$record->{isbn} = $data->{isbn}[0]->{content} if $data->{isbn};
    	
    	  #authors and editors
    	my $authors =$data->{contributors}->{contributor} ;
    	foreach my $auName (@$authors){
    		if ($auName->{'contributor_role'} eq 'author') {
    			my $fullname = $auName->{surname}.', '.$auName->{'given_name'};
    			utf8::decode($fullname);
    			push @{$record->{authors}}, $fullname;
    		} elsif ($auName->{'contributor_role'} eq 'editor') {
    			my $fullname = $auName->{surname}.', '.$auName->{'given_name'};
    			utf8::decode($fullname);
    			push @{$record->{editors}}, $fullname;
    		}
    	}
    	if($dataSuperior and !$record->{editors}){
    		my $editors = $dataSuperior->{contributors}->{contributor};
    		foreach my $edName (@$editors){
    			if($edName->{'contributor_role'} eq 'editor'){
    				my $fullname = $edName->{surname}.', '.$edName->{'given_name'};
    				utf8::decode($fullname);
    				push @{$record->{editors}}, $fullname;
    			}
    		}
    	}
    	
    	  # get publication type
    	$record->{type} = $xRefTypeMapping{$data->{doi}->{type}};
    	
    	  # CASE 1: journalArticle
    	if ($record->{type} eq 'journalArticle') {
    		$record->{mainTitle} = $data->{'article_title'} if $data->{article_title};
    		$record->{publication} = $data->{'journal_title'} if $data->{'journal_title'};
    		$record->{issue} = $data->{issue} if $data->{issue};
    		$record->{volume} = $data->{volume} if $data->{volume};
    		$record->{pagesStart} = $data->{'first_page'} if $data->{'first_page'};
    		$record->{pagesEnd} = $data->{'last_page'} if $data->{'last_page'};
    		$record->{articleType} = 'original';
    		$record->{issn} = $data->{issn}[0]->{content} if $data->{issn};
    	}
    	
    	($record->{type} eq 'journalArticle' || $record->{type} eq 'conference') && ($record->{isQualityControlled} = '1');
    	
    	  # CASE 2: conference
    	if ($record->{type} eq 'conference') {
    		$record->{mainTitle} = $data->{'article_title'} if $data->{'article_title'};
    		$record->{pagesStart} = $data->{'first_page'} if $data->{'first_page'};
    		$record->{pagesEnd} = $data->{'last_page'} if $data->{'last_page'};
    		$record->{publication} = $data->{'volume_title'} if $data->{'volume_title'};
    	}
    	
    	  # CASE 3: bookChapter
    	if ($record->{type} eq 'bookChapter') {
    		$record->{mainTitle} = $data->{'article_title'} if $data->{'article_title'};
    		$record->{volume} = $data->{volume} if $data->{volume};
    		$record->{pagesStart} = $data->{'first_page'} if $data->{'first_page'};
    		$record->{pagesEnd} = $data->{'last_page'} if $data->{'last_page'};
    		$record->{publication} = $data->{'volume_title'} if $data->{'volume_title'};
    		$record->{seriesTitle} = $data->{'series_title'} if $data->{'series_title'};
    	}
    	
    	  # CASE 4: book
    	if ($record->{type} eq 'book') {
    		$record->{volume} = $data->{volume} if $data->{volume};
    		$record->{mainTitle} = $data->{'volume_title'} if $data->{'volume_title'};
    		$record->{series} = $data->{'series_title'} if $data->{'series_title'};
    	}
    	
    	  # CASE 5: bookEditor
    	if ($record->{type} eq 'bookEditor'){
    		$record->{volume} = $data->{volume} if $data->{volume};
    		$record->{mainTitle} = $data->{'volume_title'} if $data->{'volume_title'};
    		$record->{publication} = $data->{'series_title'} if $data->{'series_title'};
    	}
    	
    	
    	  # final steps: add to database and web output
    	my $result;
    	$result->{recordId} = $self->addImportedRecord ($accountOId, $record);
    	$result->{recordTitle} = $record->{mainTitle};
    	push @{$web->{records}}, $result;
    
    } #end of foreach (@doiArray)
   
    $web->{messageField} = 'via CrossRef-Import at ' . $tm;
    $self->printTemplate( 'importDoiStatus', $web);