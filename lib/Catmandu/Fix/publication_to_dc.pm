package Catmandu::Fix::publication_to_dc;

use Catmandu::Sane;
use Moo;
use Dancer qw(setting);

my $DRIVER_TYPES = {
    journalArticle => 'article',
    book => 'book',
    bookChapter => 'bookPart',
    bookEditor => 'book',
    bookReview => 'review',
    conference => 'conferenceObject',
    dissertation => 'doctoralThesis',
    biDissertation => 'doctoralThesis',
    biPostdocThesis => 'doctoralThesis',
    biBachelorThesis => 'bachelorThesis',
    biMasterThesis => 'masterThesis',
    licentiateThesis => 'masterThesis',
    workingPaper => 'workingPaper',
    preprint => 'preprint',
    report => 'report',
    patent => 'patent',
    newspaperArticle => 'contributionToPeriodical',
};

my $DINI_TYPES = {
    journalArticle => 'article',
    book => 'book',
    bookChapter => 'bookPart',
    bookEditor => 'book',
    bookReview => 'review',
    conference => 'conferenceObject',
    dissertation => 'doctoralThesis',
    biDissertation => 'doctoralThesis',
    biPostdocThesis => 'doctoralThesis',
    biBachelorThesis => 'bachelorThesis',
    biMasterThesis => 'masterThesis',
    workingPaper => 'workingPaper',
    preprint => 'preprint',
    report => 'report',
    patent => 'patent',
    newspaperArticle => 'contributionToPeriodical',
};

my $LANG_MAP = {
   chi => 'cmn',
   ger => 'deu',
   fre => 'fra',
   rum => 'ron',
   gre => 'ell',
};

my $host = setting('host');

sub fix {

    my ($self, $pub) = @_;

    my $type = $DRIVER_TYPES->{$pub->{type}} || 'other';
    my $dc = {
        identifier => [ "$host/publication/$pub->{_id}" ],
        type => [$type, "info:eu-repo/semantics/$type"]
    };
    my $dini_type = $DINI_TYPES->{$pub->{type}} || 'other';
    push @{$dc->{type}}, "doc-type:$dini_type";
    ($pub->{type} eq 'biPostdocThesis') && (push @{$dc->{type}}, "posdoctoral thesis/habilitation");
    push @{$dc->{type}}, "text";

    $dc->{title}       = [ $pub->{title} ] if $pub->{title};
    $dc->{date}        = [ $pub->{year} ] if $pub->{year};
    $dc->{description} = $pub->{abstract}->[0]->{text} if $pub->{abstract};
    $dc->{publisher}   = [ $pub->{publisher} ] if $pub->{publisher};
    if (my $lang = $pub->{language}) {
    	push @{$dc->{language} ||= []},
            map {
                $LANG_MAP->{$_->{iso}} ? $LANG_MAP->{$_->{iso}} : $_->{iso}
            } @$lang;
    }

    if (my $auth = $pub->{author}) {
        $dc->{creator} = [ map { $_->{full_name} || join(', ', $_->{last_name}, $_->{first_name}) } @$auth ];
    }

    if (my $ed = $pub->{editor}) {
	push @{$dc->{contributor} ||= []},
        map { $_->{full_name} || join(', ', $_->{last_name}, $_->{first_name}) } @$ed;
    }

    if (my $trans = $pub->{translatedWorkAuthor}) {
	push @{$dc->{contributor} ||= []},
        map { $_->{full_name} || join(', ', $_->{last_name}, $_->{first_name}) } @$trans;
    }

    push @{$dc->{contributor} ||= []}, $pub->{corporate_editor} if $pub->{corporate_editor};

    if (my $keyword = $pub->{keyword}) {
        push @{$dc->{subject} ||= []}, @$keyword;
    }

    # if (my $ddc = $pub->{ddc}) {
    #     foreach (@$ddc) {
    #        push @{$dc->{subject} ||= []}, "DDC:$_->{class}";
    #     }
    # }

    push @{$dc->{source}}, $pub->{citation}->{ama};

    if (my $file = $pub->{file}->[0]) {
       $dc->{format} = [ $file->{content_type} ];
       push (@{$dc->{identifier}}, "$host/download/".$pub->{_id}."/".$file->{file_id});
       if ($file->{access_level} eq 'open_access') {
           push @{$dc->{rights} ||= []}, "info:eu-repo/semantics/openAccess";
       } else {
           push @{$dc->{rights} ||= []}, "info:eu-repo/semantics/restrictedAccess";
       }
    } else {
        push @{$dc->{rights} ||= []}, "info:eu-repo/semantics/restrictedAccess";
    }

    if ($pub->{issn}) {
        push @{$dc->{relation} ||= []}, map { "info:eu-repo/semantics/altIdentifier/issn/$_" } @{$pub->{issn}};
    }

    if ($pub->{isbn}) {
        push @{$dc->{relation} ||= []}, map { "info:eu-repo/semantics/altIdentifier/isbn/$_" } @{$pub->{isbn}};
    }

    push @{$dc->{relation} ||= []}, "info:eu-repo/semantics/altIdentifier/doi/$pub->{doi}" if $pub->{doi};

    push (@{$dc->{relation}}, "info:eu-repo/semantics/altIdentifier/arxiv/$pub->{external_id}->{arxiv}") if $pub->{external_id}->{arxiv};
    push (@{$dc->{relation}}, "info:eu-repo/semantics/altIdentifier/urn/$pub->{external_id}->{urn}") if $pub->{external_id}->{urn};
    push @{$dc->{relation}}, "info:eu-repo/semantics/altIdentifier/wos/$pub->{external_id}->{isi}" if $pub->{external_id}->{isi};
    push @{$dc->{relation}}, "info:eu-repo/semantics/altIdentifier/pmid/$pub->{external_id}->{pmid}" if $pub->{external_id}->{pmid};

    if ($pub->{fp7}) {
        push @{$dc->{relation} ||= []}, "info:eu-repo/grantAgreement/EC/" . $pub->{fp7};
    } elsif ($pub->{fp6}) {
        push @{$dc->{relation} ||= []}, "info:eu-repo/grantAgreement/EC/" . $pub->{fp6};
    }

    $dc;

}

1;
