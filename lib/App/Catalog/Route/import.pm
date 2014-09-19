package App::Catalog::Route::import;

use Dancer ':syntax';
use Try::Tiny;
use App::Catalog::Controller::Import;

post '/record/import' => sub {
	my $p = params;

    #return template "add_new" unless $p->{source} && $p->{id};
	my $pub;
    try {
        $pub = import_publication($p->{source}, $p->{id});
    } catch {
        template "add_new", {error => "Could not import ID $p->{id} from source $p->{source}."};
    }

	template "backend/forms/$pub->{type}", $pub;
};

=head1 PREFIX /record

    Bibliographic importer

=head2 POST /import

    Input is a source and an identifier. Returns a form with imported data.

=cut

1;
