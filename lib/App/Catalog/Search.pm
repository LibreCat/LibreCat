package App::Catalog::Search;

use App::Catalog::Helper;
use Dancer ':syntax';
use Catmandu::Util qw(:is :array);

sub handle_request {
    my ($par) = @_;
    my $p;
    my $query = $par->{q} || "";
    my $id = $par->{bisId};
    $p->{limit} = $par->{limit};

    my $personInfo = h->getPerson($id);

    my $facets = {
        coAuthor => {
            terms => {
                field   => 'author.personNumber',
                size    => 100,
                exclude => [$id]
            }
        },
        coEditor => {
            terms => {
                field   => 'editor.personNumber',
                size    => 100,
                exclude => [$id]
            }
        },
        openAccess => { terms => { field => 'file.openAccess', size => 10 } },
        qualityControlled =>
            { terms => { field => 'qualityControlled', size => 1 } },
        popularScience =>
            { terms => { field => 'popularScience', size => 1 } },
        nonlu => { terms => { field => 'isNonLuPublication', size => 1 } },
        hasMedline => { terms => { field => 'hasMedline', size => 1 } },
        hasArxiv   => { terms => { field => 'hasArxiv',   size => 1 } },
        hasInspire => { terms => { field => 'hasInspire', size => 1 } },
        hasIsi     => { terms => { field => 'hasIsi',     size => 1 } },
        submissionStatus =>
            { terms => { field => 'submissionStatus', size => 10 } },
    };
    $p->{facets} = $facets;

    my $rawquery      = $query;
    my $doctypequery  = "";
    my $publyearquery = "";

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

    $p->{q}      = $query;
    $p->{facets} = $facets;

    #Sorting
    my $personStyle = $par->{personStyle};
    my $personSorto = $par->{personSort};

    my $standardSort = h->config->{store}->{default_sort};
    my $standardSruSort;
    foreach (@$standardSort) {
        $standardSruSort .= "$_->{field},,";
        $standardSruSort .= $_->{order} eq "asc" ? "1 " : "0 ";
    }
    $standardSruSort = substr( $standardSruSort, 0, -1 );

    my $personSruSort;
    if ( $personSorto and $personSorto ne "" ) {
        $personSruSort = "publishingYear,,";
        $personSruSort .= $personSorto eq "asc" ? "1 " : "0 ";
        $personSruSort .= "dateLastChanged,,0";
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
                { terms => { field => 'documentType', size => 30 } }
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
                    field => 'publishingYear',
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

    $hits->{bisId}   = $par->{bisId};
    $hits->{style}
        = $par->{style}
        || $personStyle
        || h->config->{store}->{default_fd_style};
    $hits->{personSort}  = $par->{personSort};
    $hits->{personStyle} = $par->{personStyle};

    template 'home.tt', $hits;
}

get '/search' => sub {
	if(!session->{role}){
		forward '/myPUB/login', {error_message => "Please log in!"};
	}
	
    my $params = params;
    my $id = params->{id} ? params->{id} : "73476";    # for development only
    my $personInfo = h->getPerson($id);

    $params->{q} = "person=$id AND hide<>$id" if !$params->{q};
    $params->{limit} = h->config->{store}->{maximum_page_size}
        if !$params->{limit};

    $params->{bisId} = $id;
    my $personStyle;
    my $personSort;
    if (    $personInfo->{stylePreference}
        and $personInfo->{stylePreference} =~ /(\w{1,})\.(\w{1,})/ )
    {
        if ( array_includes( h->config->{lists}->{styles}, $1 ) ) {
            $personStyle = $1 unless $1 eq "pub";
        }
        $personSort = "publishingyear." . $2;
    }
    elsif ( $personInfo->{stylePreference}
        and $personInfo->{stylePreference} !~ /\w{1,}\.\w{1,}/ )
    {
        if (array_includes(
                h->config->{lists}->{styles},
                $personInfo->{stylePreference}
            )
            )
        {
            $personStyle = $personInfo->{stylePreference}
                unless $personInfo->{stylePreference} eq "pub";
        }
    }

    if ( $personInfo->{sortPreference} ) {
        $personSort = $personInfo->{sortPreference};
    }
    $params->{personStyle} = $personStyle || "";
    $params->{personSort}  = $personSort  || "";

    handle_request($params);
};

get qr{/hidden/*} => sub {
    my $id = params->{id} ? params->{id} : "73476";
    my $style = params->{style} || "pub";
    my $p = {
        q      => "person=$id AND hide=$id",
        facets => "",
        limit  => params->{limit} || h->config->{store}->{maximum_page_size},
        start  => params->{start} || 0,
        style  => $style,
        id     => $id,
    };

    handle_request($p);
};

1;
