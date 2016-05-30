package App::Api;

=head1 NAME

App::Api - REST API access to backend modules.

=cut

use Catmandu::Sane;
use Dancer qw(:syntax);

use all qw(App::Api::Route::*);

=head1 SEE ALSO

L<App::Api::Route::FileStore>
=cut

1;

__END__
