package Citation;

use Catmandu::Sane;
use Catmandu -load;
use Catmandu::Util qw(:array);
use Catmandu::Store::MongoDB;
use JSON;

Catmandu->load(':up');
my $conf = Catmandu->config;
my $store = Catmandu->store('citation');

my $genreMap = $conf->{citation}->{type_map};

=head1 getCitation()

Takes one ID and one optional style and gets the corresponding citations.
If no style was specified, it gets the ID's citations for all styles in mongodatabases.pl.

=cut

sub getCitation {
	my ($id, $style) = @_;
	my $citation = $store->bag->get($id);
	if ($style){
		return $citation->{$style};
	}
	else {
		return $citation;
	}
}

=head1 overwriteCitations()

Overwrites ALL citations for the given IDs in the database.

For initial creation of DB.

Takes list of internal IDs, gets all info for each corresponding record,
creates citations for styles given in conf/extension/mongodatabases.pl and writes them to a mongoDB
(db name specified in mongodatabases.pl)
Checks for existing IDs, deletes existing record and writes new one.

=cut

sub updateAllCitations {
	my $verbose = shift;
	my @ids = @_;

	foreach my $recId (@ids) {
		id2citations($recId, $verbose, "");
	}

}

=head1 updateCitations

Handles one ID at a time, but can handle several styles.

For updated and new records, that need their citations updated.

Also for debugging: call with one ID and one (changed) style to update only this record's citations.

=cut

sub updateCitations {
	my ($id, $verbose, @styles) = @_;
	if ($id eq ''){
		print "Processing ALL IDs and your list of styles."."\n" if $verbose;
		my $ids = $store->bag->pluck("_id")->to_array;
		print "Got all IDs from the DB... moving on."."\n" if $verbose;
		foreach (@$ids){
			id2citations($_, $verbose, "", @styles);
		}
	}
	else {
		print "Processing ID $id and your list of styles."."\n" if $verbose;
		id2citations($id, $verbose, "", @styles);
	}
}

=head1 deleteCitations

Deletes all citations for the given ID.

=cut

sub deleteCitations {
	my $id = shift;
	$store->bag->delete($id);
}

=head1 deleteStyle

Takes a style name as value and deletes this field in ALL records

=cut

sub deleteStyle {
	my $verbose = shift;
	my @styles = shift;
	return unless @styles;
	my @f = map { "remove_field('$_')" } @styles;
	my $fixer = Catmandu::Fix->new(fixes => @f);
	$fixer->fix($store->bag);
}
	#my @ids = $store->bag->selectField("_id");
	# my $ids = $store->bag->pluck("_id")->to_array;
	# foreach (@$ids){
	# 	my $rec = $store->bag->get($_);
	# 	foreach my $style (@style){
	# 		delete $rec->{$style};
	# 		print "Deleted field $style for ID $_"."\n" if $verbose;
	# 	}
	# 	my $written = $store->bag->add($rec);
	# }
#}

=head1 id2citation

Updated version of id2citations for new backend

=cut

sub index_citation_update {
	my ($rec, $verbose, $returnType, @styles) = @_;

	$returnType = '' if !$returnType;
	my $lang = "en"; #default
	my $recId = $rec->{_id};

	my $status_ref = {
		'submitted'   => 'Submitted',
		'accepted'    => 'Accepted',
		'inpress'     => 'In Press',
		'unpublished' => 'Unpublished',
	};

	my $rec_prep;
	$rec_prep->{'title'} = $rec->{'title'};

	# Only continue if title is present
	if (!$rec_prep->{title}){
		print "no title for ID $recId, no further processing for this ID"."\n" if $verbose;
		return;
	}

	if($rec->{'alternative_title'}){
		$rec_prep->{'originalTitle'} = @{$rec->{'alternative_title'}}[0];
	}

	# journal/book info
	$rec_prep->{'container-title'}  = $rec->{'publication'} if $rec->{'publication'}; #journal title
	$rec_prep->{'collection-title'} = $rec->{'series_title'} if $rec->{'series_title'};
	$rec_prep->{'publisher'}        = $rec->{'publisher'} if $rec->{'publisher'};
	$rec_prep->{'issn'}             = $rec->{publication_identifier}->{issn} if $rec->{publication_identifier} and $rec->{publication_identifier}->{issn};
	$rec_prep->{'ISBN'}             = $rec->{publication_identifier}->{isbn} if $rec->{publication_identifier} and $rec->{publication_identifier}->{isbn};
	$rec_prep->{'volume'}           = $rec->{'volume'} if $rec->{'volume'};
	$rec_prep->{'issue'}            = $rec->{'issue'} if $rec->{'issue'};
	$rec_prep->{'page-first'}       = $rec->{page}->{start} if $rec->{page} and $rec->{page}->{start};
	$rec_prep->{'page'}             = $rec->{page}->{start} if $rec->{page} and $rec->{page}->{start};
	$rec_prep->{'page'}            .= '–'.$rec->{page}->{end} if ($rec->{page} and $rec->{page}->{start} and $rec->{page}->{end});
	utf8::decode($rec_prep->{'page'}) if $rec_prep->{'page'};
	$rec_prep->{'number-of-pages'}  = $rec->{page}->{count} if $rec->{page} and $rec->{page}->{count};

	my $publ_year = ($rec->{'publication_status'} && ($rec->{'publication_status'} =~ /submitted|accepted|inpress|unpublished/)) ? $status_ref->{$rec->{'publication_status'}} : $rec->{'year'};
	push (@{$rec_prep->{'issued'}->{'date-parts'}}, [$publ_year]);

	$rec_prep->{'sort-year'}        = $rec->{'year'};
	$rec_prep->{'publisher-place'}  = $rec->{'place'} if $rec->{'place'};
	$rec_prep->{'edition'}          = $rec->{'edition'} if $rec->{'edition'};
	$rec_prep->{'status'}           = $rec->{'publication_status'} if $rec->{'publication_status'};

	# conference info
	$rec_prep->{'event'}            = $rec->{conference}->{name} if $rec->{conference} and $rec->{conference}->{name};
	$rec_prep->{'event-place'}      = $rec->{conference}->{location} if $rec->{conference} and $rec->{conference}->{location};

	# publication identifier
	$rec_prep->{'DOI'}              = $rec->{'doi'} if $rec->{'doi'};
	$rec_prep->{'urn'}              = $rec->{'urn'} if $rec->{'urn'};
	$rec_prep->{'pubmedId'}         = $rec->{external_id}->{pmid} if $rec->{external_id} and $rec->{external_id}->{pmid};
	$rec_prep->{'arxivId'}          = $rec->{external_id}->{arxiv} if $rec->{external_id} and $rec->{external_id}->{arxiv};
	$rec_prep->{'patentNumber'}     = $rec->{ipn} if $rec->{ipn};
	$rec_prep->{'patentClassification'} = $rec->{ipc} if $rec->{ipc};

	$rec_prep->{'type'}          = $rec->{type};

	if($rec->{author}){
		foreach my $author (@{$rec->{author}}) {
			my $author_rec;
			$author_rec->{'given'}  = $author->{first_name};
			$author_rec->{family} = $author->{last_name};
			$author_rec->{full}   = $author->{full_name};
			$rec_prep->{sort_author} = $author->{full_name};

			push @{$rec_prep->{'author'}}, $author_rec;
		}
	}

	if($rec->{translator}){
		foreach my $translator (@{$rec->{translator}}) {
			my $translator_rec;
			$translator_rec->{'given'}  = $translator->{'first_name'};
			$translator_rec->{'family'} = $translator->{'last_name'};
			$translator_rec->{'full'}   = $translator->{'full_name'};

			push @{$rec_prep->{'translator'}}, $translator_rec;
		}
	}

	if($rec->{editor}){
		foreach my $editor (@{$rec->{editor}}) {
			my $editor_rec;
			$editor_rec->{'given'}  = $editor->{'first_name'};
			$editor_rec->{'family'} = $editor->{'last_name'};
			$editor_rec->{'full'}   = $editor->{'full_name'};
			push @{$rec_prep->{'editor'}}, $editor_rec ;
		}
	}


	if($rec->{'corporate_editor'}){
		foreach my $ce (@{$rec->{'corporate_editor'}}){
			my $literal;
			$literal->{'literal'} = $ce;
			push @{$rec_prep->{'editor'}}, $literal;
		}
	}

	$rec_prep->{'type'} = $genreMap->{$rec_prep->{'type'}};
	$rec_prep->{'publstatus'} = $rec->{'publication_status'} if $rec->{'publication_status'};
	$rec_prep->{'recordid'} = $recId;

	my $debug;
	$debug = $rec_prep;

	my $rec_array;
	push @$rec_array, $rec_prep;

	my $json = new JSON;
	my $json_citation = $json->encode($rec_array);

	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new;

	use Sys::Hostname;
	my $host = hostname;
	my $hostname;
	if($host =~ /pub-dev.ub/){
		$hostname = 'pub-dev.ub';
	}
	elsif($host =~ /pub3.ub/){
		$hostname = 'pub3.ub';
	}
	else {
		$hostname = 'pub';
	}
	my $citeproc_url = 'http://' . $hostname . '.uni-bielefeld.de' . $conf->{citation}->{url};

	my $citation;
	my $styleList = $conf->{citation}->{styles};

	# wurden styles uebergeben, verarbeite nur diese
	if (@styles){
		foreach my $style (@styles) {
			if (($returnType eq '' && array_includes($styleList, $style)) or $returnType ne ''){
				my $data;
				if ($style eq 'dgps'){
					push @$data, ("locale" => "de");
				}
				else {
					push @$data, ("locale" => $lang);
				}
				push @$data, ("style" => $style);
				push @$data, ("format" => "html");
				push @$data, ("input" => $json_citation);

				my $my_response = $ua->post($citeproc_url, Content => $data);
				$debug = $my_response;
				#return $debug;

				my $citation_ref = $json->decode($my_response->{_content});
				#$debug = $citation_ref;

				if(@$citation_ref[0]->{citation}){
					$citation->{$style} = @$citation_ref[0]->{citation};
				}
				else {
					$citation->{$style} = "";
				}
				$lang = "en";
			}
		}
	}
	# sonst verarbeite alle styles aus conf Datei
	else {
		foreach my $style (@$styleList){
			my $data;
			if($style eq "dgps"){
				push @$data, ("locale" => "de");
			}
			else {
				push @$data, ("locale" => $lang);
			}
			push @$data, ("style" => $style);
			push @$data, ("format" => "html");
			push @$data, ("input" => $json_citation);

			my $my_response = $ua->post($citeproc_url, Content => $data);
			$debug = $my_response;
			my $citation_ref = $json->decode($my_response->{_content});
			#$debug = $citation_ref;

			$citation->{'_id'} = $recId;
			if(@$citation_ref[0]->{citation}){
				$citation->{$style} = @$citation_ref[0]->{citation};
			}
			else {
				$citation->{$style} = "";
			}
		}
	}

	if($returnType ne ""){
		return $debug if $returnType eq 'debug';
		return $citation->{$styles[0]};
	}
	else {
		return $citation;
	}
}

=head1 id2citation

Updated version of id2citations for new backend

=cut

sub id2citation {
	my ($rec, $verbose, $returnType, @styles) = @_;

	$returnType = '' if !$returnType;
	my $lang = "en"; #default
	my $recId = $rec->{_id};

	my $status_ref = {
		'submitted'   => 'Submitted',
		'accepted'    => 'Accepted',
		'inpress'     => 'In Press',
		'unpublished' => 'Unpublished',
	};

	my $rec_prep;
	$rec_prep->{'title'} = $rec->{'title'};

	# Only continue if title is present
	if (!$rec_prep->{title}){
		print "no title for ID $recId, no further processing for this ID"."\n" if $verbose;
		return;
	}

	if($rec->{'alternative_title'}){
		$rec_prep->{'originalTitle'} = @{$rec->{'alternative_title'}}[0];
	}

	# journal/book info
	$rec_prep->{'container-title'}  = $rec->{'publication'} if $rec->{'publication'}; #journal title
	$rec_prep->{'collection-title'} = $rec->{'series_title'} if $rec->{'series_title'};
	$rec_prep->{'publisher'}        = $rec->{'publisher'} if $rec->{'publisher'};
	$rec_prep->{'issn'}             = $rec->{publication_identifier}->{issn} if $rec->{publication_identifier} and $rec->{publication_identifier}->{issn};
	$rec_prep->{'ISBN'}             = $rec->{publication_identifier}->{isbn} if $rec->{publication_identifier} and $rec->{publication_identifier}->{isbn};
	$rec_prep->{'volume'}           = $rec->{'volume'} if $rec->{'volume'};
	$rec_prep->{'issue'}            = $rec->{'issue'} if $rec->{'issue'};
	$rec_prep->{'page-first'}       = $rec->{page}->{start} if $rec->{page} and $rec->{page}->{start};
	$rec_prep->{'page'}             = $rec->{page}->{start} if $rec->{page} and $rec->{page}->{start};
	$rec_prep->{'page'}            .= '–'.$rec->{page}->{end} if ($rec->{page} and $rec->{page}->{start} and $rec->{page}->{end});
	utf8::decode($rec_prep->{'page'}) if $rec_prep->{'page'};
	$rec_prep->{'number-of-pages'}  = $rec->{page}->{count} if $rec->{page} and $rec->{page}->{count};

	my $publ_year = ($rec->{'publication_status'} && ($rec->{'publication_status'} =~ /submitted|accepted|inpress|unpublished/)) ? $status_ref->{$rec->{'publication_status'}} : $rec->{'year'};
	push (@{$rec_prep->{'issued'}->{'date-parts'}}, [$publ_year]);

	$rec_prep->{'sort-year'}        = $rec->{'year'};
	$rec_prep->{'publisher-place'}  = $rec->{'place'} if $rec->{'place'};
	$rec_prep->{'edition'}          = $rec->{'edition'} if $rec->{'edition'};
	$rec_prep->{'status'}           = $rec->{'publication_status'} if $rec->{'publication_status'};

	# conference info
	$rec_prep->{'event'}            = $rec->{conference}->{name} if $rec->{conference} and $rec->{conference}->{name};
	$rec_prep->{'event-place'}      = $rec->{conference}->{location} if $rec->{conference} and $rec->{conference}->{location};

	# publication identifier
	$rec_prep->{'DOI'}              = $rec->{'doi'} if $rec->{'doi'};
	$rec_prep->{'urn'}              = $rec->{'urn'} if $rec->{'urn'};
	$rec_prep->{'pubmedId'}         = $rec->{external_id}->{pmid} if $rec->{external_id} and $rec->{external_id}->{pmid};
	$rec_prep->{'arxivId'}          = $rec->{external_id}->{arxiv} if $rec->{external_id} and $rec->{external_id}->{arxiv};
	$rec_prep->{'patentNumber'}     = $rec->{ipn} if $rec->{ipn};
	$rec_prep->{'patentClassification'} = $rec->{ipc} if $rec->{ipc};

	$rec_prep->{'type'}          = $rec->{type};

	if($rec->{author}){
		foreach my $author (@{$rec->{author}}) {
			my $author_rec;
			$author_rec->{'given'}  = $author->{first_name};
			$author_rec->{family} = $author->{last_name};
			$author_rec->{full}   = $author->{full_name};
			$rec_prep->{sort_author} = $author->{full_name};

			push @{$rec_prep->{'author'}}, $author_rec;
		}
	}

	if($rec->{translator}){
		foreach my $translator (@{$rec->{translator}}) {
			my $translator_rec;
			$translator_rec->{'given'}  = $translator->{'first_name'};
			$translator_rec->{'family'} = $translator->{'last_name'};
			$translator_rec->{'full'}   = $translator->{'full_name'};

			push @{$rec_prep->{'translator'}}, $translator_rec;
		}
	}

	if($rec->{editor}){
		foreach my $editor (@{$rec->{editor}}) {
			my $editor_rec;
			$editor_rec->{'given'}  = $editor->{'first_name'};
			$editor_rec->{'family'} = $editor->{'last_name'};
			$editor_rec->{'full'}   = $editor->{'full_name'};
			push @{$rec_prep->{'editor'}}, $editor_rec ;
		}
	}


	if($rec->{'corporate_editor'}){
		foreach my $ce (@{$rec->{'corporate_editor'}}){
			my $literal;
			$literal->{'literal'} = $ce;
			push @{$rec_prep->{'editor'}}, $literal;
		}
	}

	$rec_prep->{'type'} = $genreMap->{$rec_prep->{'type'}};
	$rec_prep->{'publstatus'} = $rec->{'publication_status'} if $rec->{'publication_status'};
	$rec_prep->{'recordid'} = $recId;

	my $debug;
	$debug = $rec_prep;

	my $rec_array;
	push @$rec_array, $rec_prep;

	my $json = new JSON;
	my $json_citation = $json->encode($rec_array);

	use LWP::UserAgent;
	my $ua = LWP::UserAgent->new;

	use Sys::Hostname;
	my $host = hostname;
	my $hostname;
	if($host =~ /pub-dev.ub/){
		$hostname = 'pub-dev.ub';
	}
	elsif($host =~ /pub-dev2.ub/){
		$hostname = 'pub-dev2.ub';
	}
	else {
		$hostname = 'pub';
	}
	my $citeproc_url = 'http://' . $hostname . '.uni-bielefeld.de' . $conf->{citation}->{url};

	my $mongo_hash;
	my $styleList = $conf->{citation}->{styles};

	# wurden styles uebergeben, verarbeite nur diese
	if (@styles){
		$mongo_hash = $store->bag->get($recId);

		foreach my $style (@styles) {
			if (($returnType eq '' && array_includes($styleList, $style)) or $returnType ne ''){
				my $data;
				if ($style eq 'dgps'){
					push @$data, ("locale" => "de");
				}
				else {
					push @$data, ("locale" => $lang);
				}
				push @$data, ("style" => $style);
				push @$data, ("format" => "html");
				push @$data, ("input" => $json_citation);

				my $my_response = $ua->post($citeproc_url, Content => $data);
				$debug = $my_response;
				#return $debug;

				my $citation_ref = $json->decode($my_response->{_content});
				#$debug = $citation_ref;

				if(@$citation_ref[0]->{citation}){
					$mongo_hash->{$style} = @$citation_ref[0]->{citation};
				}
				else {
					$mongo_hash->{$style} = "";
				}
				$lang = "en";
			}
		}
	}
	# sonst verarbeite alle styles aus conf Datei
	else {
		foreach my $style (@$styleList){
			my $data;
			if($style eq "dgps"){
				push @$data, ("locale" => "de");
			}
			else {
				push @$data, ("locale" => $lang);
			}
			push @$data, ("style" => $style);
			push @$data, ("format" => "html");
			push @$data, ("input" => $json_citation);

			my $my_response = $ua->post($citeproc_url, Content => $data);
			$debug = $my_response;
			my $citation_ref = $json->decode($my_response->{_content});
			#$debug = $citation_ref;

			$mongo_hash->{'_id'} = $recId;
			if(@$citation_ref[0]->{citation}){
				$mongo_hash->{$style} = @$citation_ref[0]->{citation};
			}
			else {
				$mongo_hash->{$style} = "";
			}
		}
	}

	if($returnType ne ""){
		return $debug if $returnType eq 'debug';
		return $mongo_hash->{$styles[0]};
	}
	else {
		$store->bag->add($mongo_hash);
		print "Stored citations for record $recId in the mongoDB!\n" if $verbose;
	}
}

1;
