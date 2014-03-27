package App::Catalog::Person;

se Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;

prefix '/person' => sub {

	post '/settings_update' => sub {
		my $id = params->{id} ? params->{id} : "73476";

		my $personInfo = h->getPerson($id);
		my $personStyle;
		my $personSort;
		if($personInfo->{stylePreference} and $personInfo->{stylePreference} =~ /(\w{1,})\.(\w{1,})/){
			if(array_includes(h->config->{lists}->{styles},$1)){
				$personStyle = $1 unless $1 eq "pub";
			}
			$personSort = $2;
		}
		elsif($personInfo->{stylePreference} and $personInfo->{stylePreference} !~ /\w{1,}\.\w{1,}/){
			if(array_includes(h->config->{lists}->{styles},$personInfo->{stylePreference})){
				$personStyle = $personInfo->{stylePreference} unless $personInfo->{stylePreference} eq "pub";
			}
		}
		
		if($personInfo->{sortPreference}){
			$personSort = $personInfo->{sortPreference};
		}
		
		my $style = params->{style} || $personStyle || h->config->{store}->{default_fd_style};
		delete(params->{style}) if params->{style};
		
		my $sort = params->{'sort'} || $personSort || "";
		
		$personInfo->{stylePreference} = $style;
		$personInfo->{sortPreference} = $sort if $sort ne "";

		h->authorityUser->add($personInfo);
		
		forward '/';
	};

	post '/authorid_update' => sub {

		my $id = params->{id} ? params->{id} : "73476";
		my $personInfo = h->getPerson($id);
		my @identifier = qw(googleScholar researcher authorclaim scopus orcid github arxiv inspire);
		map{ $personInfo->{$_} = params->{$_} ? params->{$_} : "" } @identifier;
		my $bag = h->authorityUser->add($personInfo);
		
		forward '/';

	};


};

1;
