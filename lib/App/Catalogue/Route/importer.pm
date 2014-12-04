package App::Catalogue::Route::importer;

=head1 NAME

    App::Catalogue::Route::importer - central handler for import routes

=cut

use Dancer ':syntax';
use Try::Tiny;
use App::Catalogue::Controller::Import;
use Dancer::Plugin::Auth::Tiny;

=head2 POST /myPUB/record/import

    Input is a source and an identifier.
    Returns a form with imported data.

=cut
post '/myPUB/record/import' => needs login => sub {
	my $p = params;

    my $pub;
    try {
        $pub = import_publication($p->{source}, $p->{id});
        if ($pub) {
					my $tmpl = $pub->{type} || 'journalArticle';
          return template "backend/forms/$tmpl", $pub;
        } else {
            return template "add_new",
                {error => "No record found with ID $p->{id} in $p->{source}."};
        }
    } catch {
        return template "add_new", {error => "Could not import ID $p->{id} from source $p->{source}."};
    };

};

1;
