package App::Catalog::Route::import;

=head1 NAME

    App::Catalog::Route::import - central handler for import routes

=cut

use Dancer ':syntax';
use Try::Tiny;
use App::Catalog::Controller::Import;

=head2 POST /import

    Input is a source and an identifier.
    Returns a form with imported data.

=cut

post '/record/import' => sub {
	my $p = params;

    my $pub;
    try {
        $pub = import_publication($p->{source}, $p->{id});
        if ($pub) {
            return template "backend/forms/$pub->{type}", $pub;
        } else {
            return template "add_new",
                {error => "No record found with ID $p->{id} in $p->{source}."};
        }
    } catch {
        return template "add_new", {error => "Could not import ID $p->{id} from source $p->{source}."};
    };

};

1;
