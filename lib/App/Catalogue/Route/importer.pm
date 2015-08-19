package App::Catalogue::Route::importer;

=head1 NAME

App::Catalogue::Route::importer - central handler for import routes

=cut

use Dancer ':syntax';
use Try::Tiny;
use Dancer::Plugin::Auth::Tiny;
use App::Helper;
use App::Catalogue::Controller::Importer;

=head2 POST /myPUB/record/import

Returns a form with imported data.

=cut
post '/myPUB/record/import' => needs login => sub {
	my $p = params;

    my $pub;
	my $user = h->get_person( session->{personNumber} );
	my $edit_mode = params->{edit_mode} || $user->{edit_mode} || "";

    try {
        $pub = App::Catalogue::Controller::Importer->new(
			id => $p->{id},
			source => $p->{source},
			)->fetch;

        if ($pub) {
			$pub->{_id} = h->new_record('publication');
			my $type = $pub->{type} || 'journalArticle';
			my $templatepath = "backend/forms";
			$pub->{department} = $user->{department};

			if (($edit_mode and $edit_mode eq "expert") or (!$edit_mode and session->{role} eq "super_admin")){
				$templatepath .= "/expert";
			}

			return template $templatepath . "/$type", $pub;
        } else {
            return template "backend/add_new",
                {error => "No record found with ID $p->{id} in $p->{source}."};
        }
    } catch {
        return template "backend/add_new", {error => "Could not import ID $p->{id} from source $p->{source}."};
    };

};

1;
