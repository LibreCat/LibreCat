package LibreCat::App::Search;

use Catmandu::Sane;
use Dancer qw(:syntax);

use all qw(LibreCat::App::Search::Route::*);
use LibreCat::App::Helper;

get qr{/en/*} => sub {
    session lang => "en";
    template '/websites/index_publication.tt', {bag => "home"};
};

get '/' => sub {
    template '/websites/index_publication.tt', {bag => "home"};
};

1;
