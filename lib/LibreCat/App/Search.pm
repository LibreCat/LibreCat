package LibreCat::App::Search;

use Catmandu::Sane;
use Dancer qw(:syntax);

use all qw(LibreCat::App::Search::Route::*);
use LibreCat::App::Helper;

get '/' => sub {
    template 'index';
};

1;
