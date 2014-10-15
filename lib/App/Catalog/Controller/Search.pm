package App::Catalog::Controller::Search;

use App::Catalog::Helper;
use Catmandu::Util qw(:is :array);
use Dancer qw/:syntax/;
use Exporter qw/import/;

our @EXPORT = qw/search_publication/;

# handling the search
#####################
sub search_publication {
    my $par = shift;

    my $p;
    my $id = session->{personNumber};
    $p->{limit} = $par->{limit} ||= h->config->{store}->{default_searchpage_size};
    $p->{start} = $par->{start} ||= 0;

    my $query;

    my $account = h->getAccount(session->{user})->[0];
    if($account->{reviewer} and $par->{modus} eq "reviewer"){
    	#$query .= join(' OR ');
    	 my $revdep = "";
    	 foreach my $rev (@{$account->{reviewer}}){
    	 	$revdep .= "department=$rev->{department}->{id} OR ";
    	 }
    	 $revdep =~ s/ OR $//g;
    	 $query = $revdep;
    }
    elsif($account->{dataManager} and $par->{modus} eq "dataManager"){
    	my $mgrdep = "";
    	$query = "documenttype=researchData AND ";
    	foreach my $mgr (@{$account->{dataManager}}){
    		$mgrdep .= "department=$mgr->{department}->{id} OR ";
    	}
    	$mgrdep =~ s/ OR $//g;
    	$query .= $mgrdep;
    }
    elsif ($par->{modus} eq "admin"){
    	$query = "";
    }
    elsif ( $par->{modus} =~ /^delegate/ and array_includes($account->{delegate}, $par->{delegate_id}) ) {
        $query = "person=$par->{delegate_id}";
    }
    else{
    	$query = "person=$id";
    }

    if($par->{q}){
    	$query = $query ne "" ? $query . " AND " . $par->{q} : $par->{q};
    }

    my $personInfo = h->getPerson($id);

    my $personStyle;
    my $personSorto;
    if ($personInfo->{stylePreference} and $personInfo->{stylePreference} =~ /(\w{1,})\.(\w{1,})/ ){
        if (array_includes(h->config->{lists}->{styles}, $1)) {
            $personStyle = $1 unless $1 eq "pub";
        }
        $personSorto = "publishingyear." . $2;
    }
    elsif ($personInfo->{stylePreference} and $personInfo->{stylePreference} !~ /\w{1,}\.\w{1,}/ ){
        if (array_includes(h->config->{lists}->{styles}, $personInfo->{stylePreference})){
            $personStyle = $personInfo->{stylePreference} unless $personInfo->{stylePreference} eq "pub";
        }
    }

    if ( $personInfo->{sortPreference} ) {
        $personSorto = $personInfo->{sortPreference};
    }
    $par->{personStyle} = $personStyle || "";
    $par->{personSort}  = $personSorto  || "";

    my $facets = {
        coAuthor => {
            terms => {
                field   => 'author.id',
                size    => 100,
                exclude => [$id]
            }
        },
        coEditor => {
            terms => {
                field   => 'editor.id',
                size    => 100,
                exclude => [$id]
            }
        },
        openAccess => { terms => { field => 'file.open_access', size => 10 } },
        qualityControlled => { terms => { field => 'quality_controlled', size => 1 } },
        popularScience => { terms => { field => 'popular_science', size => 1 } },
        nonlu => { terms => { field => 'extern', size => 1 } },
        submissionStatus => { terms => { field => 'status', size => 10 } },
        department => { terms => {field => 'department.id', size => 1000}},
    };
    $p->{facets} = $facets;

    my $rawquery      = $query;
    my $doctypequery  = "";
    my $publyearquery = "";

    if ( params->{submissionstatus} and ref params->{submissionstatus} ne 'ARRAY' ){
        $query        .= " AND submissionstatus=" . params->{submissionstatus};
        $doctypequery .= " AND submissionstatus=" . params->{submissionstatus};
    }

    if(params->{department} and ref params->{department} ne "ARRAY"){
    	$query .= " AND department=" . params->{department};
    	$doctypequery .= " AND department=" . params->{department};
    }

    # separate handling of publication types (for separate facet)
    if ( params->{publicationtype}
        and ref params->{publicationtype} eq 'ARRAY' )
    {
        my $tmpquery = "";
        foreach ( @{ params->{publicationtype} } ) {
            $tmpquery .= "documenttype=" . $_ . " OR ";
        }
        $tmpquery =~ s/ OR $//g;
        $query        .= " AND (" . $tmpquery . ")";
        $doctypequery .= " AND (" . $tmpquery . ")";
    }
    elsif ( params->{publicationtype}
        and ref params->{publicationtype} ne 'ARRAY' )
    {
        $query        .= " AND documenttype=" . params->{publicationtype};
        $doctypequery .= " AND documenttype=" . params->{publicationtype};
    }

    #separate handling of publishing years (for separate facet)
    if ( params->{publishingyear}
        and ref params->{publishingyear} eq 'ARRAY' )
    {
        my $tmpquery = "";
        foreach ( @{ params->{publishingyear} } ) {
            $tmpquery .= "publishingyear=" . $_ . " OR ";
        }
        $tmpquery =~ s/ OR $//g;
        $query         .= " AND (" . $tmpquery . ")";
        $publyearquery .= " AND (" . $tmpquery . ")";
    }
    elsif ( params->{publishingyear}
        and ref params->{publishingyear} ne 'ARRAY' )
    {
        $query         .= " AND publishingyear=" . params->{publishingyear};
        $publyearquery .= " AND publishingyear=" . params->{publishingyear};
    }

    $query = h->clean_cql($query) if $query ne "";
    $publyearquery = h->clean_cql($publyearquery) if $publyearquery ne "";
    $doctypequery = h->clean_cql($doctypequery) if $doctypequery ne "";

    $p->{q}      = $query;
    $p->{facets} = $facets;

    my $standardSort = h->config->{store}->{default_sort_backend};
    my $standardSruSort;
    foreach (@$standardSort) {
        $standardSruSort .= "$_->{field},,";
        $standardSruSort .= $_->{order} eq "asc" ? "1 " : "0 ";
    }
    $standardSruSort = substr( $standardSruSort, 0, -1 );

    my $personSruSort;
    if ( $personSorto and $personSorto ne "" ) {
        $personSruSort = "publishingyear,,";
        $personSruSort .= $personSorto eq "asc" ? "1 " : "0 ";
        $personSruSort .= "datelastchanged,,0";
    }
    my $paramSruSort;
    if ( $par->{'sort'} && ref $par->{'sort'} eq 'ARRAY' ) {
        foreach ( @{ $par->{'sort'} } ) {
            if ( $_ =~ /(.*)\.(.*)/ ) {
                $paramSruSort .= "$1,,";
                $paramSruSort .= $2 eq "asc" ? "1 " : "0 ";
            }
        }
        $paramSruSort = substr( $paramSruSort, 0, -1 );
    }
    elsif ( $par->{'sort'} && ref $par->{'sort'} ne 'ARRAY' ) {
        if ( $par->{'sort'} =~ /(.*)\.(.*)/ ) {
            $paramSruSort .= "$1,,";
            $paramSruSort .= $2 eq "asc" ? "1" : "0";
        }
    }
    my $sruSort = "";
    $sruSort = $paramSruSort ||= $personSruSort ||= $standardSruSort ||= "";
    $p->{sort} = $sruSort;

    my $hits = h->search_publication($p);

    foreach (qw(next_page last_page page previous_page pages_in_spread)) {
		$hits->{$_} = $hits->$_;
	}

    my $d = {
        q      => $rawquery . $publyearquery,
        limit  => 1,
        facets => {
            documentType =>
                { terms => { field => 'type', size => 30 } }
        }
    };
    my $dochits = h->search_publication($d);
    $hits->{dochits} = $dochits;

    my $y = {
        q      => $rawquery . $doctypequery,
        limit  => 1,
        facets => {
            year => {
                terms => {
                    field => 'year',
                    size  => 100,
                    order => 'reverse_term'
                }
            }
        }
    };
    my $yearhits = h->search_publication($y);
    $hits->{yearhits} = $yearhits;

    my $titleName;
    $titleName .= $personInfo->{givenName} . " " if $personInfo->{givenName};
    $titleName .= $personInfo->{surname} . " "   if $personInfo->{surname};

    if ($titleName) {
        $hits->{personPageTitle} = "Publications " . $titleName;
    }

    $hits->{style} = $par->{style} || $personStyle || h->config->{store}->{default_fd_style};
    $hits->{personSort}  = $par->{personSort};
    $hits->{personStyle} = $par->{personStyle};
    $hits->{modus} = $par->{modus};

    template 'home.tt', $hits;
}

1;
