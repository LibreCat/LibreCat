package App::Search::Route::project;

=head1 NAME

App::Search::Route::project - handling routes for project pages.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;

=head2 GET /project/:id

Project splash page for :id.

=cut
get qr{/project/(P\d+)/*} => sub {
    my ($id) = splat;
    my $proj = h->project->get($id);

    my $pub = h->publication->search(cql_query => "project=$id", limit => 100);
    $proj->{project_publication} = $pub;

    template 'project/project', $proj;
};

get qr{/project/*} => sub {
	if(params->{ttyp} and params->{ttyp} eq "hist_proj"){
		my $hits;
		my $p = {
			limit => params->{limit} ||= h->config->{store}->{default_searchpage_size},
			start => params->{start} ||= 0,
		};
		
		$p->{q};
		if(params->{q}){
			$p->{q} = params->{q};
		}
		elsif (params->{ftext}) {
			my @textbits = split " ", params->{ftext};
			foreach (@textbits){
				push @{$p->{q}}, $_;
			}
			#$p->{q} =~ s/^ AND //g;
		}
		
		if(params->{active} and params->{active} eq "yes"){
			push @{$p->{q}}, "isactive=1" if params->{active} eq "yes";
			push @{$p->{q}}, "isactive=0" if params->{active} eq "no";
		}
		
		push @{$p->{q}}, "funder=\"" . params->{funder} . "\"" if params->{funder};
		
		if(params->{sc39}){
			push @{$p->{q}}, "sc39=1" if params->{sc39} eq "yes";
		}
		
		push @{$p->{q}}, "startyear=" . params->{startYear} if params->{startYear} && params->{startYear} ne "";
		push @{$p->{q}}, "endyear=" . params->{endYear} if params->{endYear} && params->{endYear} ne "";
		
		push @{$p->{q}}, "department=" . params->{department} if params->{department} && params->{department} ne "";
		
		my $facets = {
			startYear => {terms => {field => 'start_year.exact', size => 100}},
			endYear => {terms => {field => 'end_year.exact', size => 100}},
			funder => {terms => {field => 'funder.exact', size => 100}},
		};
		$p->{facets} = $facets;
		
		my $cqlsort;
		if(params->{sorting} and params->{sorting} =~ /(\w{1,})\.(\w{1,})/){
			$cqlsort = $1 . ",,";
			$cqlsort .= $2 eq "asc" ? "1" : "0";
		}
		$p->{sorting} = $cqlsort;
		
		if(params->{ttyp} and params->{ttyp} eq "hist_proj"){
			push @{$p->{q}}, "department=10023";
		}
		
		if(params->{projecttype}){
			push @{$p->{q}}, "projecttype=\"" . params->{projecttype} . "\"";
		}
		
		#$p->{q} = h->clean_cql($p->{q});
		$hits = h->search_project($p);
		
		$hits->{bag} = 'project';
		template "hist_proj/bup_liste_hist_proj.tt", $hits;
	}
	else{
		status 'not_found';
		template 'websites/404', {path => request->{referer}};
	}
};

1;
