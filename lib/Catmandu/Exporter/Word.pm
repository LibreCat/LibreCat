package Catmandu::Exporter::Word;

use Catmandu::Sane;
use Catmandu;
use Moo;
use MIME::Base64 qw(encode_base64);
use Encode qw(encode_utf8);

extends 'Catmandu::Exporter::Cite';

my $HEADER = <<EOF;
MIME-Version: 1.0
Content-Type: multipart/related; boundary="----=_NextPart_01CD9FB3.A56B2FC0"

This document is a Web archive file.  If you are seeing this message, this means your browser or editor doesn't support Web archive files.  For more information on the Web archive format, go to http://officeupdate.microsoft.com/office/webarchive.htm

------=_NextPart_01CD9FB3.A56B2FC0
Content-Location: file:///C:/D057922B/myfile.htm
Content-Transfer-Encoding: base64
Content-Type: text/html; charset="utf-8"

EOF

my $FOOTER = <<EOF;
------=_NextPart_01CD9FB3.A56B2FC0
Content-Location: file:///C:/D057922B/myfile_files/filelist.xml
Content-Transfer-Encoding: quoted-printable
Content-Type: text/xml; charset="utf-8"

<xml xmlns:o=3D"urn:schemas-microsoft-com:office:office">
 <o:MainFile HRef=3D"../myfile.htm"/>
 <o:File HRef=3D"filelist.xml"/>
</xml>
------=_NextPart_01CD9FB3.A56B2FC0--

EOF

my $HTML_HEADER = <<EOF;
<html xmlns:v="urn:schemas-microsoft-com:vml"
xmlns:o="urn:schemas-microsoft-com:office:office"
xmlns:w="urn:schemas-microsoft-com:office:word"
xmlns:m="http://schemas.microsoft.com/office/2004/12/omml"
xmlns:mv="http://macVmlSchemaUri" xmlns="http://www.w3.org/TR/REC-html40">

<head>
<meta name=Title content="">
<meta name=Keywords content="">
<meta http-equiv=Content-Type content="text/html; charset=utf-8">
<meta name=ProgId content=Word.Document>
<link rel=File-List href="myfile_files/filelist.xml">
<style>
<!--
\@font-face
    {font-family:"Arial Unicode MS";
    panose-1:2 11 6 4 2 2 2 2 2 4;
    mso-font-charset:0;
    mso-generic-font-family:auto;
    mso-font-pitch:variable;
    mso-font-signature:-134238209 -371195905 63 0 4129279 0;}
p.MsoNormal
    {mso-style-unhide:no;
    mso-style-qformat:yes;
    mso-style-parent:"";
    margin:0cm;
    margin-bottom:6.0pt;
    mso-pagination:widow-orphan;
    font-size:12.0pt;
    font-family:"Arial Unicode MS";}
\@page WordSection1
    {size:595.0pt 842.0pt;
    margin:72.0pt 90.0pt 72.0pt 90.0pt;
    mso-header-margin:35.4pt;
    mso-footer-margin:35.4pt;
    mso-paper-source:0;}
div.WordSection1
    {page:WordSection1;}
-->
</style>
</head>
<body lang=EN-US style='tab-interval:36.0pt'>
<div class=WordSection1>

EOF

my $HTML_FOOTER = <<EOF;

</div>
</body>
</html>

EOF

sub encoding {':crlf'}

sub BUILD {
    $_[0]->{_buf} = $HTML_HEADER;
}

sub _add_cite {
    my ($self, $cite) = @_;
    $cite =~ s!</?div[^>]*>!!g;    # strip div tags
    $self->{_buf} .= encode_utf8("<p class=MsoNormal>$cite</p>");
}

sub commit {
    my ($self) = @_;
    $self->fh->print($HEADER);
    $self->fh->print(encode_base64($self->{_buf} . $HTML_FOOTER));
    $self->fh->print($FOOTER);
}

1;
