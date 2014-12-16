package Catmandu::Fix::publication_to_ris;

use Catmandu::Sane;
use Moo;
use Catmandu::Util qw(array_group_by trim);

my $TYPES = {
    book             => 'BOOK',
    bookChapter      => 'CHAP',
    bookEditor       => 'BOOK',
    conference       => 'CONF',
    dissertation     => 'THES',
    journalArticle   => 'JOUR',
    licentiateThesis => 'THES',
    researchData => 'DATA',
};

sub fix {
    my ($self, $pub) = @_;

    my $type = $pub->{documentType};

    my $ris; 

    $ris->{TY} = $TYPES->{$type} || 'GEN';
    $ris->{ID} = $pub->{_id};
    $ris->{TI} = $pub->{mainTitle} if $pub->{mainTitle};
    $ris->{VL} = trim($pub->{volume}) if $pub->{volume};
    $ris->{IS} = $pub->{issue} if $pub->{issue};
    $ris->{KW} = $pub->{keyword} if $pub->{keyword};
    $ris->{U3} = "PUB:ID $pub->{_id}";

    my $val;

    if ($val = $pub->{publisher}) {
        $ris->{PB} = $val;
    }

    if ($pub->{pagesStart} && $pub->{pagesEnd}) {
        $ris->{SP} = $pub->{pagesStart};
        $ris->{EP} = $pub->{pagesEnd};
    }

    given ($type) {
	    when (/journalArticle/) { $ris->{JF} = $pub->{publication} if $pub->{publication}; }
        default                 { $ris->{T2} = $pub->{publication} if $pub->{publication}; }
    }

    if (my $au = $pub->{author}) {
	$ris->{AU} = [ map {
                ($_{givenName} && $_{surname}) ? "$_->{givenName} $_->{surname}"
                        : "$_->{fullName}";
                } @$au ];
    }
    if (my $ed = $pub->{editor}) {
	$ris->{ED} = [ map {
                ($_->{givenName} && $_->{surname}) ? "$_->{givenName} $_->{surname}"
                        : "$_->{fullName}";
                } @$ed ];
    }

    if ($val = $pub->{publishingYear}) {
        $ris->{PY} = $val;
    }

    if ($val = $pub->{abstract} and @$val) {
        $ris->{AB} = $val->[0]->{text};
    }

    if ($val = $pub->{isbn} and @$val) {
        $ris->{SN} = $val->[0];
    } elsif ($val = $pub->{issn} and @$val) {
        $ris->{SN} = $val->[0];
    }

    if ($val = $pub->{isi}) {
        $ris->{U1} = "wos:id $val";
    }

    if ($pub->{doi}) {
        push @{ $ris->{UR} },"http://dx.doi.org/$pub->{doi}";
    } elsif (ref $pub->{doiInfo} eq 'ARRAY') {
        push @{ $ris->{UR} },"http://dx.doi.org/$pub->{doiInfo}->[0]->{doi}";
    } elsif ($pub->{doiInfo}) {
        push @{ $ris->{UR} },"http://dx.doi.org/$pub->{doiInfo}->{doi}";
    }

#    if ($val = $pub->{link} and @$val) {
#    	push @{ $ris->{UR} }, $val->[0]->{url};
#    }
    if ( $pub->{urn} ) {
	push @{ $ris->{UR} }, "http://nbn-resolving.de/" . $pub->{urn};
    }

    $ris;
}

1;
