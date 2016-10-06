use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::MimeType';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok {$pkg->new()} 'lives_ok';

my $mime = $pkg->new();
can_ok $mime, 'content_type';

my %map = (
    txt      => 'text/plain',
    pdf      => 'application/pdf',
    json     => 'application/json',
    bib      => 'text/x-bibtex',
    whatever => 'application/octet-stream',
);

is($mime->content_type('test.' . $_), $map{$_}, "mime type for $_ ok")
    for keys %map;

done_testing;
