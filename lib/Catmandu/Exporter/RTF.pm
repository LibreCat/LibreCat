package Catmandu::Exporter::RTF;

use Catmandu::Sane;
use Catmandu;
use Moo;

extends 'Catmandu::Exporter::Cite';

my $HEADER = <<EOF;
{\\rtf1\\ansi\\deff0\\adeflang1025
{\\fonttbl{\\f0 Arial;}}
\\f0\\fs22

EOF

my $FOOTER = <<EOF;
 }

EOF

sub encoding {':utf8'}

sub BUILD {
    $_[0]->{_buf} = $HEADER;
}

sub _add_cite {
    my ($self, $pub) = @_;

    my $cite;
    my $title;
    my $links;

    if ($self->style eq "short") {
        $cite  = $pub->{citation}{short};
        $title = $pub->{title};
    }
    else {
        $cite = $pub->{citation}{$self->style};
    }

    my $bag = $pub->{type} eq "research_data" ? "data" : "publication";

    if ($self->explinks and $self->explinks eq "yes") {
        $links
            = "\\line PUB: {\\field{\\*\\fldinst HYPERLINK https://pub.uni-bielefeld.de/$bag/$pub->{_id}}{\\fldrslt https://pub.uni-bielefeld.de/$bag/$pub->{_id}}}";

        if ($pub->{doi}) {
            $links
                .= "\\line DOI: {\\field{\\*\\fldinst HYPERLINK https://doi.org/$pub->{doi}}{\\fldrslt $pub->{doi}}}";
        }

        if (my $ext = $pub->{external_id}) {
            if ($ext->{isi}) {
                $links
                    .= "\\line WoS: {\\field{\\*\\fldinst HYPERLINK https://ws.isiknowledge.com/cps/openurl/service?url_ver=Z39.88-2004&rft_id=info:ut/$ext->{isi}}{\\fldrslt $ext->{isi}}}";
            }

            if ($ext->{pmid}) {
                $links .= "\\line PMID: $ext->{pmid}";
            }

            if ($ext->{arxiv}) {
                $links
                    .= "\\line arXiv: {\\field{\\*\\fldinst HYPERLINK http://arxiv.org/abs/$ext->{arxiv}}{\\fldrslt $ext->{arxiv}}}";
            }

            if ($ext->{inspire}) {
                $links
                    .= "\\line Inspire: {\\field{\\*\\fldinst HYPERLINK http://inspirehep.net/record/$ext->{inspire}}{\\fldrslt $ext->{inspire}}}";
            }

            if ($ext->{phillister}) {
                $links
                    .= "\\line PhilLister: {\\field{\\*\\fldinst HYPERLINK http://phillister.ub.uni-bielefeld.de/$bag/$ext->{phillister}}{\\fldrslt $ext->{phillister}}}";
            }

            if ($ext->{ahf}) {
                $links
                    .= "\\line AHF: {\\field{\\*\\fldinst HYPERLINK http://www.oldenbourg.de/verlag/ahf/hbo.php?F=titel&T=HB&ID=$ext->{ahf}}{\\fldrslt $ext->{ahf}}}";
            }
        }
    }
    elsif ($self->explinks and $self->explinks eq "pub") {
        $links
            = "\\line PUB: {\\field{\\*\\fldinst HYPERLINK https://pub.uni-bielefeld.de/$bag/$pub->{_id}}{\\fldrslt https://pub.uni-bielefeld.de/$bag/$pub->{_id}}}";
    }

# all those hexadecimal characters longer than 2 (\\' in rtf will treat the following two characters as hex - but only two!)
    my $hexlist = {
        "152" => "\\'4f\\'45"
        ,   # latin capital letter OE - substituted by capital letters O and E
        "153" => "\\'6f\\'65"
        ,    # latin small letter oe - substituted by small letters o and e
        "160" => "\\'53"
        , # latin capital letter S with caron - substituted by capital letter S
        "161" => "\\'73"
        ,    # latin small letter s with caron - substituted by small letter s
        "178" => "\\'59"
        , # latin capital letter Y with diaeresis - substituted by capital letter Y
        "192" => "\\'66"
        ,  # latin small f with hook, function - substituted by small letter f
        "2013" => "\\endash",
        "2014" => "\\emdash",
        "2018" => "\\lquote",
        "2019" => "\\rquote",

        #"201A" => # single low-9 quotation mark
        "201C" => "\\ldblquote",
        "201D" => "\\rdblquote",

        #"201E" => # double low-9 quotation mark
        #"2020" => # dagger
        #"2021" => # double dagger
        "2022" => "\\bullet",

        #"2026" => # horizontal ellipsis
        #"2030" => # per thousand sign
        #"20AC" => # euro sign
        #"2122" => #trade mark sign
    };

    # replace all html tags in the citation with their rtf equivalent
    $cite =~ s/<em>(.*?)<\/em>/\{\\i $1}/g;
    $cite =~ s/<i>(.*?)<\/i>/\{\\i $1}/g;
    $cite =~ s/&amp;/&/g;
    $cite
        =~ s/<span style="text-decoration:underline;">(.*?)<\/span>/{\\u $1}/g;
    $cite =~ s/<br \/>/\\line /g;
    $cite =~ s/“/\\ldblquote/g;
    $cite =~ s/”/\\rdblquote /g;

    my $indent;
    if ($cite
        =~ /<div style="text-indent:-25px; padding-left:25px;padding-bottom:0px;">(.*?)<\/div>/
        )
    {
        $indent = 1;
        $cite
            =~ s/<div style="text-indent:-25px; padding-left:25px;padding-bottom:0px;">(.*?)<\/div>/\\li380 \\fi-380 $1 /g;
    }
    $cite =~ s/<div>(.*?)<\/div>/$1/g;

    my $hyperlink;
    if ($cite =~ /<a href\=\"(.*?)\"(\starget\=\"_blank\")*>(.*?)<\/a>/) {
        $cite =~ s/<a href\=\"(.*?)\"(\starget\=\"_blank\")*>(.*?)<\/a>/____/g;
        $hyperlink = "{\\field{\\*\\fldinst HYPERLINK $1}{\\fldrslt $3}}";
    }

    $cite =~ s/ /___/g;

    $title =~ s/ /___/g if $title;

# convert everything that isn't rtf or a space into hex (necessary for dealing with utf8/non-utf8 characters)
# utf8::encode worked, but delivered (the Catmandu typical) double encodings in the file
# utf8::decode got rid of the double encodings but the decoded string was not allowed in the rtf format
# - so: hex, it is!
    $cite
        =~ s/([^\\\\u|\\\\i|\\\\ldblquote|\\\\rdblquote|\\\\li380|\\\\fi\-380|\\\\line|___|\{|\}|\(|\)|[0-9]|\s])/sprintf("\\'%02x",ord($1))/eg;
    $title
        =~ s/([^\\\\u|\\\\i|\\\\line|___|\{|\}|\(|\)|[0-9]|\s])/sprintf("\\'%02x",ord($1))/eg
        if $title;

# BUT rtf only works with hex codes consisting of 2 characters, everything that's longer gets cut after 2 (see hash above)
# So, replace everything that has a longer hex representation with stuff from the list or nothing at all
    while ($cite =~ /\\\'(\d{3,4})/) {
        my $hexv = $1;
        if ($hexlist->{$hexv}) {
            $cite =~ s/\\\'$hexv/$hexlist->{$hexv} /g;
        }
        else {
            $cite =~ s/\\\'$hexv//g;
        }
    }

    if ($title) {
        while ($title =~ /\\\'(\d{3,4})/) {
            my $hexv = $1;
            if ($hexlist->{$hexv}) {
                $title =~ s/\\\'$hexv/$hexlist->{$hexv} /g;
            }
            else {
                $title =~ s/\\\'$hexv//g;
            }
        }
    }
    my $rtftitle
        = "{\\field{\\*\\fldinst HYPERLINK https://pub.uni-bielefeld.de/$bag/$pub->{_id}}{\\fldrslt "
        . $title
        . "}}\\line "
        if $title;

    #utf8::decode($cite);
    my $citestring = "{\\pard ";
    $citestring .= $rtftitle if $rtftitle;
    $citestring .= $cite;

    #$citestring .= $hyperlink if $hyperlink;
    if ($indent and $links) {
        $citestring .= "\\li380 " . $links;
    }
    elsif ($links) {
        $citestring .= $links;
    }
    $citestring .= "\\line\\par}\n";
    $citestring =~ s/____/$hyperlink/g if $hyperlink;
    $citestring =~ s/___/ /g;
    $self->{_buf} .= $citestring;
}

sub commit {
    my ($self) = @_;
    $self->fh->print($self->{_buf} . $FOOTER);
}

1;
