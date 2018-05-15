package LibreCat::App::Search;

=head1 NAME

LibreCat::App::Search - The central top level frontend module.
Integrates all routes needed for frontend searching and displaying.

=cut

use Catmandu::Sane;
use Dancer qw(:syntax);

use all qw(LibreCat::App::Search::Route::*);
use LibreCat::App::Helper;

=head2 GET /

Returns the template 'index', the start page of the LibreCat app.

=cut

get '/' => sub {
    template 'index';
};

1;
