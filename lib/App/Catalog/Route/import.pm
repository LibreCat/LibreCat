package App::Catalog::Route::import;

=head1 NAME

    App::Catalog::Route::import - central handler for import routes

=cut

use Dancer ':syntax';
use Try::Tiny;
use App::Catalog::Controller::Import;
use Dancer::Plugin::Auth::Tiny;

=head2 POST /myPUB/record/import

    Input is a source and an identifier. Returns a form with imported data.

=cut
post '/myPUB/record/import' => needs login => sub {
	my $p = params;

    my $pub;
    try {
        $pub = import_publication($p->{source}, $p->{id});
    } catch {
        template "add_new", {error => "Could not import ID $p->{id} from source $p->{source}."};
    }

	template "backend/forms/$pub->{type}", $pub;
};

1;
