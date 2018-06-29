use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::App::Catalogue::Route::file';
    use_ok $pkg;
}

require_ok $pkg;

is LibreCat::App::Catalogue::Route::file::str_format( "%o", i => 1, f => "DS.0", e => "pdf", o => "test.pdf" ), "test.pdf";
is LibreCat::App::Catalogue::Route::file::str_format( "%i-%f.%e", i => 1, f => "DS.0", e => "pdf", o => "test.pdf" ), "1-DS.0.pdf";

done_testing;
