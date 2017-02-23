package LibreCat::App::Search::Route::department;

=head1 NAME

LibreCat::App::Search::Route::department - handling routes for department pages.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;

=head2 GET /department

Display departments list.

=cut

get '/department' => sub {
    return template 'department/list';
};

1;
