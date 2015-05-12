package App::Search;

use Catmandu::Sane;
use Dancer qw(:syntax);

use all qw(App::Search::Route::*);

get '/' => sub {
    template '/websites/index_publication.tt', {bag => "home"};
};

1;
