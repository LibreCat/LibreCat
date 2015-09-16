package Citation;

use Catmandu::Sane;
use Catmandu -load;
use Catmandu::Util qw(:array);
use Catmandu::Error;
use Moo;
use LWP::UserAgent;

Catmandu->load(':up');
my $conf = Catmandu->config->{citation};

has styles => (is => 'ro', default => sub { ['default'] });
has all => (is => 'ro');

sub BUILD {
	my ($self) = @_;
	if ($self->all) {
		$self->styles = $conf->{csl}->{styles};
	}
	# check styles
}

sub _request {
	my ($self, $content) = @_;

	my $ua = LWP::UserAgent->new();
	my $res = = $ua->post($conf->{csl}->{url}, Content => $content);

	return $res->{_rc} eq '200'
		? $json->decode($res->{_content})[0]->{citation} : '';
}

sub create {
	my ($self, $data) = @_;

	unless ($data->{title}) {
		Catmandu::BadVal->throw('Title field is missing');
	}

	my $cite;

	if ($conf->{engine} eq 'template') {
		return { default => export_to_string('Template', $data, { template => $conf->{template}->{template_path} }) };
	} else {
		my $csl_json = export_to_string(JSON, $data, { array => 1, fix => 'fixes/to_csl.fix' });
		foreach my $s (@{$self->{styles}}) {
			$cite->{$s} = $self->_request(["style => $s", "format => 'html'", "input => $csl_json"]);
		}

		return $cite;
	}

}

__END__

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

	# Only continue if title is present
#	if (!$rec_prep->{title}){
#		print "no title for ID $recId, no further processing for this ID"."\n" if $verbose;
#		return;
#	}

	if($rec->{'page'}){
		if($rec->{'page'} =~ /([^- ]+) - ([^- ]+)/ or $rec->{'page'} =~ /([^- ]+)-([^- ]+)/){
			$rec_prep->{'page-first'} = $1;
			$rec_prep->{'page'} = $1 ."–" .$2;
		}
		elsif($rec->{'type'} eq "journalArticle"){
			$rec_prep->{'page'} = $rec->{'page'};
		}
		else {
			$rec_prep->{'number-of-pages'} = $rec->{'page'};
		}
	}
	utf8::decode($rec_prep->{'page'}) if $rec_prep->{'page'};

	my $publ_year = ($rec->{'publication_status'} && ($rec->{'publication_status'} =~ /submitted|accepted|inpress|unpublished/)) ? $status_ref->{$rec->{'publication_status'}} : $rec->{'year'};
	push (@{$rec_prep->{'issued'}->{'date-parts'}}, [$publ_year]);

	$rec_prep->{'publstatus'} = $rec->{'publication_status'} if $rec->{'publication_status'};

	my $debug;
	$debug = $rec_prep;

	my $rec_array;
	push @$rec_array, $rec_prep;

	my $csl_json = $rec_prep;

	my $json = new JSON;
	my $json_citation = $json->encode($rec_array);
	#return $json_citation;

	use LWP::UserAgent;


	my $citeproc_url = 'http://::'.$conf->{citation}->{url};
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

				#my $citation_ref = $json->decode($my_response->{_content});
				my $citation_ref = $my_response->{_rc} ne "500" ? $json->decode($my_response->{_content}) : [{citation => ""}];
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
			#return $my_response;
			my $citation_ref = $my_response->{_rc} ne "500" ? $json->decode($my_response->{_content}) : [{citation => ""}];
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
		return $csl_json if $returnType eq 'csl_json';
		return $citation->{$styles[0]};
	}
	else {
		return $citation;
	}
}

1;
