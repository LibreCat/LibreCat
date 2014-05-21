package App::Catalog::Search;

use Dancer ':syntax';
use App::Catalog::Helper;
use Catmandu::Util qw(:is :array);

sub handle_request {
    my ($par) = @_;
    my $p;
    my $query = $par->{q} || "";
    my $id = $par->{bisId};
    $p->{limit} = $par->{limit};
    $p->{limit} = h->config->{store}->{default_searchpage_size} if !$par->{limit};

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
        qualityControlled =>
            { terms => { field => 'quality_controlled', size => 1 } },
        popularScience =>
            { terms => { field => 'popular_science', size => 1 } },
        nonlu => { terms => { field => 'extern', size => 1 } },
        #hasMedline => { terms => { field => 'hasMedline', size => 1 } },
        #hasArxiv   => { terms => { field => 'hasArxiv',   size => 1 } },
        #hasInspire => { terms => { field => 'hasInspire', size => 1 } },
        #hasIsi     => { terms => { field => 'hasIsi',     size => 1 } },
        submissionStatus =>
            { terms => { field => 'status', size => 10 } },
    };
    $p->{facets} = $facets;

    my $rawquery      = $query;
    my $doctypequery  = "";
    my $publyearquery = "";
    
    if ( params->{submissionstatus} and ref params->{submissionstatus} ne 'ARRAY' ){
        $query        .= " AND submissionstatus=" . params->{submissionstatus};
        $doctypequery .= " AND submissionstatus=" . params->{submissionstatus};
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

    #Sorting
    #my $personStyle = $par->{personStyle};
    #my $personSorto = $par->{personSort};

    my $standardSort = h->config->{store}->{default_sort};
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

get '/adminSearch' => sub {
	
    my $params = params;
    my $role = session->{role};
    
    if($role ne "superAdmin"){
    	redirect '/myPUB/reviewerSearch';
    }

    $params->{modus} = "admin";

    handle_request($params);
};

get '/reviewerSearch' => sub {
	
    my $params = params;
    my $role = session->{role};
    
    if($role ne "superAdmin" and $role ne "reviewer"){
    	redirect '/myPUB/search';
    }

    $params->{modus} = "reviewer";

    handle_request($params);
};

get '/search' => sub {
	
    my $params = params;
    my $role = session->{role};

    $params->{modus} = "user";

    handle_request($params);
};

1;
