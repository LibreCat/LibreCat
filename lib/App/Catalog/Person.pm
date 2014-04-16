package App::Catalog::Person;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;

prefix '/person' => sub {

	post '/preferences' => sub {
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

	post '/authorid' => sub {

		my $person = h->authority_user->get(params->{_id});
		my @identifier = keys h->config->{lists}->{author_id};
		
		map{
			$person->{$_} = params->{$_} ? params->{$_} : ""
			} @identifier;

		my $bag = h->authority_user->add($person);
		
		redirect '/myPUB';

	};


};

1;
