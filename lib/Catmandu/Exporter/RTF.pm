package Catmandu::Exporter::RTF;

use Catmandu::Sane;
use Catmandu;
use Moo;

with 'Catmandu::Exporter';

has host => (is => 'lazy');
has links => (is => 'ro', default => sub {});
has name => (is => 'ro', default => sub { 'LibreCat' });
has style => (is => 'lazy');

my $HEADER = <<EOF;
{\\rtf1\\ansi\\deff0\\adeflang1025
{\\fonttbl{\\f0 Arial;}}
\\f0\\fs22

EOF

sub BUILD {
    $_[0]->{_buf} = $HEADER;
}

sub _build_host {
    my ($self) = @_;
    state $host = Catmandu->config->{uri_base};
}

sub _build_style {
    my ($self) = @_;

    state $style = do {
        grep( $self->style, keys %{Catmandu->config->{citation}->{csl}->{styles}} )
        ? $self->style
        : Catmandu->config->{citation}->{csl}->{default_style};
    };
}

my $FOOTER = <<EOF;
 }

EOF

# all those hexadecimal characters longer than 2 (\\' in rtf will treat the following two characters as hex - but only two!)
my $HEXMAP = {
    "152" => "\\'4f\\'45",
    # latin capital letter OE - substituted by capital letters O and E
    "153" => "\\'6f\\'65"
    ,    # latin small letter oe - substituted by small letters o and e
    "160" => "\\'53"
    , # latin capital letter S with caron - substituted by capital etter S
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

sub add {
    my ($self, $pub) = @_;
    $self->_add_citation($pub);
}

sub commit {
    my ($self) = @_;
    $self->fh->print($self->{_buf} . $FOOTER);
}

sub _add_citation {
    my ($self, $pub) = @_;

    my $host = $self->host;
    my $links = $self->links;

    my $cite = $pub->{citation}{$self->style} // '';

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
        $cite
            =~ s/<a href\=\"(.*?)\"(\starget\=\"_blank\")*>(.*?)<\/a>/____/g;
        $hyperlink = "{\\field{\\*\\fldinst HYPERLINK $1}{\\fldrslt $3}}";
    }

    $cite =~ s/ /___/g;

# convert everything that isn't rtf or a space into hex (necessary for dealing with utf8/non-utf8 characters)
# utf8::encode worked, but delivered (the Catmandu typical) double encodings in the file
# utf8::decode got rid of the double encodings but the decoded string was not allowed in the rtf format
# - so: hex, it is!
    $cite
        =~ s/([^\\\\u|\\\\i|\\\\ldblquote|\\\\rdblquote|\\\\li380|\\\\fi\-380|\\\\line|___|\{|\}|\(|\)|[0-9]|\s])/sprintf("\\'%02x",ord($1))/eg;

# BUT rtf only works with hex codes consisting of 2 characters, everything that's longer gets cut after 2 (see hash above)
# So, replace everything that has a longer hex representation with stuff from the list or nothing at all
    while ($cite =~ /\\\'(\d{3,4})/) {
        my $hexv = $1;
        if ($HEXMAP->{$hexv}) {
            $cite =~ s/\\\'$hexv/$HEXMAP->{$hexv} /g;
        }
        else {
            $cite =~ s/\\\'$hexv//g;
        }
    }

    my $citestring = "{\\pard ";
    # in case you want the title displayed as link
    if ($self->style eq "short") {
        my $title = $pub->{title};
        $title =~ s/ /___/g if $title;
        $title
        =~ s/([^\\\\u|\\\\i|\\\\line|___|\{|\}|\(|\)|[0-9]|\s])/sprintf("\\'%02x",ord($1))/eg;
        while ($title =~ /\\\'(\d{3,4})/) { # why while??
            my $hexv = $1;
            if ($HEXMAP->{$hexv}) {
                $title =~ s/\\\'$hexv/$HEXMAP->{$hexv} /g;
            }
            else {
                $title =~ s/\\\'$hexv//g;
            }
        }

        my $bag = $pub->{type} eq "research_data" ? "data" : "publication";

        $citestring .= "{\\field{\\*\\fldinst HYPERLINK $host/$bag/$pub->{_id}}{\\fldrslt "
        . $title
        . "}}\\line ";
    }

    $citestring .= $cite;

    if ($indent and $links) {
        $citestring .= "\\li380 " . $self->_add_links($pub);
    }
    elsif ($links) {
        $citestring .= $self->_add_links($pub);
    }

    $citestring .= "\\line\\par}\n";
    $citestring =~ s/____/$hyperlink/g if $hyperlink;
    $citestring =~ s/___/ /g;
    $self->{_buf} .= $citestring;
}

sub _add_links {
    my ($self, $pub) = @_;

    my $host = $self->host;
    my $links = $self->links;
    my $name = $self->name;

    my $bag = $pub->{type} eq "research_data" ? "data" : "publication";

    my $line;
    $line = "\\line $name: {\\field{\\*\\fldinst HYPERLINK $host/$bag/$pub->{_id}}{\\fldrslt $host/$bag/$pub->{_id}}}";

    if ($links && $links == 1) {
        if ($pub->{doi}) {
            $line .= "\\line DOI: {\\field{\\*\\fldinst HYPERLINK https://doi.org/$pub->{doi}}{\\fldrslt $pub->{doi}}}";
        }

        if (my $ext = $pub->{external_id}) {
            if ($ext->{isi}->[0]) {
                $line .= "\\line WoS: {\\field{\\*\\fldinst HYPERLINK https://ws.isiknowledge.com/cps/openurl/service?url_ver=Z39.88-2004&rft_id=info:ut/$ext->{isi}->[0]}{\\fldrslt $ext->{isi}->[0]}}";
            }

            if ($ext->{pmid}->[0]) {
                $line .= "\\line PMID: $ext->{pmid}->[0]";
            }

            if ($ext->{arxiv}->[0]) {
                $line .= "\\line arXiv: {\\field{\\*\\fldinst HYPERLINK http://arxiv.org/abs/$ext->{arxiv}->[0]}{\\fldrslt $ext->{arxiv}->[0]}}";
            }

            if ($ext->{inspire}->[0]) {
                $line .= "\\line Inspire: {\\field{\\*\\fldinst HYPERLINK http://inspirehep.net/record/$ext->{inspire}->[0]}{\\fldrslt $ext->{inspire}->[0]}}";
            }
        }
    }

    $line;
}

1;

=pod

=head1 NAME

Catmandu::Exporter::RTF - a RTF exporter

=head1 SYNOPSIS

    use Catmandu::Exporter::RTF;

    my $rtf = Catmandu::Exporter::RTF->new(
        file => "publications.rtf",
        style => "ama",
        name => "MyRepo",
    );
    my $data = {...};

    $rtf->add($data);
    $rtf->commit;


=head1 DESCRIPTION

This L<Catmandu::Exporter> exports items in RTF by using citation styles.

=head1 CONFIGURATION

=over

=item file

Write output to a local file given by its path or file handle.  Alternatively a
scalar reference can be passed to write to a string and a code reference can be
used to write to a callback function.

=item fh

Write the output to an L<IO::Handle>. If not specified,
L<Catmandu::Util::io|Catmandu::Util/IO-functions> is used to create the output
handle from the C<file> argument or by using STDOUT.

=item fix

An ARRAY of one or more fixes or file scripts to be applied to exported items.

=item style

The citation style to use. In this case the data should have a key B<citation.$style>.

=item links

0|1. Display external links (e.g. DOI, WoS, PMID, etc)

=item name

Name of the repository to display in case you have set the option B<links to 1>.

=back

=head1 SEE ALSO

L<Catmandu::Exporter>

=cut
