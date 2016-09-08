package LibreCat::App::Api;

=head1 NAME

LibreCat::App::Api - REST API access to backend modules.

=cut

use Catmandu::Sane;
use Dancer qw(:syntax);

use all qw(LibreCat::App::Api::Route::*);

=head1 SEE ALSO

L<LibreCat::App::Api::Route::FileStore>
=cut

1;

__END__
