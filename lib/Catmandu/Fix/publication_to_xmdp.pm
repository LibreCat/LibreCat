package Catmandu::Fix::publication_to_xmdp;

use Catmandu::Sane;
use Moo;
use Dancer qw(:syntax setting);

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
    workingPaper => 'workingPaper',
    preprint => 'preprint',
    report => 'report',
    patent => 'patent',
    newspaperArticle =>  'contributionToPeriodical',

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
    newspaperArticle =>  'contributionToPeriodical',
};

my $XMDP_MAP = {
	language => 'language',
	author => 'author',
	abstract => 'abstract',
	keyword => 'subject',
	urn => 'urn',
	title => 'title',
	_id => '_id',
	file => 'file',
	year => 'date',
	defense_date => 'defenseDate',
	supervisor => 'supervisor',
	citation => 'citation',
	doi => 'doi',
};

my $THESIS_MAP = {
	biBachelorThesis => 'bachelor',
	biMasterThesis => 'master',
	biDissertation => 'thesis.doctoral',
	biPostdocThesis => 'thesis.habilitation',
};

sub fix {

    my ($self, $pub) = @_;

	my $xmdp;

    $xmdp->{dini_type} = $DINI_TYPES->{$pub->{type}} || 'other';
    foreach (keys %$XMDP_MAP) {
    	$xmdp->{$XMDP_MAP->{$_}} = $pub->{$_};
    }

    #if ($xmdp->{defense_date} =~ /(\d{4}-\d{2}-\d{2})/) {
    #    $xmdp->{defense_date} = $1;
    #} else {
        $xmdp->{defense_date} = $pub->{year} . "-01-01"; # ugly hack for fake the dnb parser
#    }

    if ($pub->{type} =~ /^bi/) {
		$xmdp->{thesisLevel} = $THESIS_MAP->{$pub->{type}};
		$xmdp->{thesis} = '1';
	}
    $xmdp->{institution} = setting('institution');
	$xmdp->{host} = setting('host');
    $xmdp;

}

1;
