package Catmandu::Fix::publication_to_ris;

use Catmandu::Sane;
use Moo;
use Catmandu::Util qw/trim/;
use App::Helper;

my $TYPES = {
    book => 'BOOK',
    bookChapter => 'CHAP',
    bookEditor => 'BOOK',
    conference => 'CONF',
    dissertation => 'THES',
    journalArticle => 'JOUR',
    licentiateThesis => 'THES',
    researchData => 'DATA',
};

sub fix {
    my ($self, $pub) = @_;

    my $type = $pub->{type};

    my $ris;

    $ris->{TY} = $TYPES->{$type} || 'GEN';
    $ris->{ID} = $pub->{_id};
    $ris->{TI} = $pub->{title} if $pub->{title};
    $ris->{VL} = trim($pub->{volume}) if $pub->{volume};
    $ris->{IS} = $pub->{issue} if $pub->{issue};
    $ris->{KW} = $pub->{keyword} if $pub->{keyword};
    $ris->{PY} = $pub->{year} if $pub->{year};
    $ris->{UR} = h->host . "/". $pub->{_id};
    $ris->{PB} = $pub->{publisher} if $pub->{publisher};

    my $val;

    if ($pub->{pagesStart} && $pub->{pagesEnd}) {
        $ris->{SP} = $pub->{pagesStart};
        $ris->{EP} = $pub->{pagesEnd};
    }

    if ($type eq 'journalArticle') {
	    $ris->{JF} = $pub->{publication} if $pub->{publication};
    } else {
        $ris->{T2} = $pub->{publication} if $pub->{publication};
    }

    if (my $au = $pub->{author}) {
	   $ris->{AU} = [ map {
            ($_{first_name} && $_{last_name}) ? "$_->{first_name} $_->{last_name}"
                : "$_->{full_name}";
            } @$au ];
    }
    if (my $ed = $pub->{editor}) {
	   $ris->{ED} = [ map {
            ($_->{first_name} && $_->{last_name}) ? "$_->{first_name} $_->{last_name}"
                : "$_->{full_name}";
            } @$ed ];
    }

    if ($val = $pub->{abstract} and @$val) {
        $ris->{AB} = $val->[0]->{text};
    }

    if ($val = $pub->{isbn} and @$val) {
        $ris->{SN} = $val->[0];
    } elsif ($val = $pub->{issn} and @$val) {
        $ris->{SN} = $val->[0];
    }

    $ris;
}

1;
