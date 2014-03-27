package App::Catalog::Admin;

use Catmandu::Sane;
use Catmandu qw(:load);
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;

Catmandu->load('/srv/www/app-catalog/index1');

get '/myPUB/add' => sub {
	template 'add_new.tt';
	#my $person = h->getPerson("86212");
	#my $departments = $person->{affiliation};
	#template 'backend/forms/researchData.tt', {recordOId => "123456789", departments => $departments};#, file => [{fileOId => 1, fileName => "file", accessLevel => "admin", dateLastUploaded => "2014-01-10", isUploadedBy => {login => "kohorst"}}]};
};

get qr{/myPUB/add/(\w{1,})/*} => sub {
	my ($type) = splat;
	#my $id = "86212";
	my $id = params->{id} ? params->{id} : "73476";
	my $personInfo = h->getPerson($id);
	my $departments = $personInfo->{affiliation};
	my $tmpl = "";
	
	if(h->config->{forms}->{publicationTypes}->{lc($type)}){
		$tmpl = "backend/forms/" . h->config->{forms}->{publicationTypes}->{$type}->{tmpl} . ".tt";
		template $tmpl, {recordOId => "123456789", department => $departments, personNumber => $id, author => [{personNumber => $id, oId => $personInfo->{sbcatId}, givenName => $personInfo->{givenName}, surname => $personInfo->{surname}, personTitle => $personInfo->{bis_personTitle}}]};
	}
	else{
		template "home.tt";
	}
};

get '/admin' => sub {

	my $tmpl = 'admin.tt';
	my $p;
	$p->{q} = "";
	if(params->{q}){
    	$p->{q} = params->{q};
    }
	elsif (params->{ftext}) {
		my @textbits = split " ", params->{ftext};
		foreach (@textbits){
			$p->{q} .= " AND " . $_;
		}
		$p->{q} =~ s/^ AND //g;
        #$p->{q} = params->{ftext};
    }

    $p->{start} = params->{start} if params->{start};
	$p->{limit} = params->{limit} ? params->{limit} : "100";
	
	if(params->{former}){
		$p->{q} .= " AND former=" if $p->{q} ne "";
		$p->{q} = "former=" if $p->{q} eq "";
		$p->{q} .= params->{former} eq "yes" ? "1" : "0";
	}
	my $cqlsort;
	if(params->{sorting} and params->{sorting} =~ /(\w{1,})\.(\w{1,})/){
		$cqlsort = $1 . ",,";
		$cqlsort .= $2 eq "asc" ? "1" : "0";
	}
	$p->{sorting} = $cqlsort;
	
	my $hits = h->search_researcher($p);
	
	$hits->{bag} = "authorlist";
	$hits->{former} = params->{former} if params->{former};
	
	template $tmpl, $hits;
};

1;
