package Catmandu::Fix::publication_to_bibtex;

use Catmandu::Sane;
use Moo;
use Catmandu::Util qw(:array trim);
#use Dancer qw(:syntax config);
use App::Helper;

my $TYPES = {
    book             => 'book',
    bookChapter      => 'inbook',
    bookEditor       => 'book',
    conference       => 'inproceedings',
    dissertation     => 'phdthesis',
    biDissertation   => 'phdthesis',
    journalArticle   => 'article',
};

sub fix {
    my ($self, $pub) = @_;

    my $type = $TYPES->{$pub->{type}} ||= 'misc';

    my $bib;
    $bib->{_citekey} = "PUB_" . $pub->{_id};
    $bib->{_type} = $type;
    $bib->{url} = h->host . "/".$pub->{_id};
    $bib->{title} = $pub->{title} if $pub->{title};
    $bib->{language} = $pub->{language}->[0]->{name} if $pub->{language}->[0]->{name};
    $bib->{keyword} = join (', ', @{$pub->{keyword}}) if $pub->{keyword};
    $bib->{volume} = trim($pub->{volume}) if $pub->{volume};
    $bib->{number} = $pub->{issue} if $pub->{issue};
    $bib->{year} = $pub->{year} if $pub->{year};
    $bib->{doi} = $pub->{doi} if $pub->{doi};
    $bib->{publisher} = $pub->{publisher} if $pub->{publisher};


    my $val;

    if ($val = $pub->{publication}) {
        if ($bib->{_type} eq 'article') {
            $bib->{journal} = $val;
        } elsif ($bib->{_type} =~ /book/) {
            $bib->{booktitle} = $val;
        } else {
            $bib->{series} = $val;
        }
    }

    if (my $au = $pub->{author}) {
        $bib->{author} = [ map {
		($_->{fist_name} && $_->{last_name}) ? "$_->{first_name} $_->{last_name}"
			: "$_->{full_name}";
		} @$au ];
    }

    if (my $ed = $pub->{editor}) {
    	$bib->{editor} = [ map {
		($_->{first_name} && $_->{last_name}) ? "$_->{first_name} $_->{last_name}"
			: "$_->{full_name}";
		} @$ed ];
    }

    if ($val = $pub->{isbn} and @$val) {
        $bib->{isbn} = $val->[0];
    }

    if ($val = $pub->{issn} and @$val) {
        $bib->{issn} = $val->[0];
    }

    if ($val = $pub->{abstract} and @$val) {
        $bib->{abstract} = $val->[0]->{text};
    }

    if ($val = $pub->{conference}) {
        $bib->{location} = $val->{location} if $val->{location};
    }

    if ($pub->{type} =~ /^bi/) {
        $bib->{school} = "Bielefeld University";#config->{institution};
    }

    if ($val = $pub->{page}) {
        $bib->{pages} = $val =~ s/-/--/;
    }

    $bib;
}

1;
