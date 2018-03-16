use Catmandu::Sane;
use warnings FATAL => 'all';
use Test::More;

# test case emerged from issue
# https://github.com/LibreCat/LibreCat/issues/420

my $file = "views/embed/links_js.tt";

my $content = `tail -1 $file`;

unlike $content, qr/\n/, "no newline at the end of file";
like $content, qr/END \%\]$/, "found template code at the end";

done_testing
