package LibreCat::App::Catalogue::Route::importer;

=head1 NAME

LibreCat::App::Catalogue::Route::importer - central handler for import routes

=cut

use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Plugin::Auth::Tiny;
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::Importer;
use Catmandu::Fix::trim as => 'trim';

=head2 POST /librecat/record/import

Returns a form with imported data.

=cut

post '/librecat/record/import' => needs login => sub {
    my $p = params;
    trim($p, 'id', 'whitespace');

    my $pub;
    my $user      = h->get_person(session->{personNumber});
    my $edit_mode = params->{edit_mode} || $user->{edit_mode} || "";

    try {
        my $data = request->upload('data') ? request->upload('data')->content : $p->{data};

        $pub = LibreCat::App::Catalogue::Controller::Importer->new(
            id     => $p->{id} // $data ,
            source => $p->{source},
        )->fetch;

        if ($pub) {
            $pub->{_id} = h->new_record('publication');
            my $type = $pub->{type} || 'journal_article';
            my $templatepath = "backend/forms";
            $pub->{department} = $user->{department};

            if (   ($edit_mode and $edit_mode eq "expert")
                or (!$edit_mode and session->{role} eq "super_admin"))
            {
                $templatepath .= "/expert";
            }

            $pub->{new_record} = 1;

            return template "$templatepath/$type", $pub;
        }
        else {
            my $id = $p->{id} // '<data>';
            return template "backend/add_new",
                {error =>
                    "No record found with ID $id in $p->{source}."};
        }
    }
    catch {
        my $id = $p->{id} // '<data>';
        return template "backend/add_new",
            {error =>
                "Could not import ID $id from source $p->{source}."};
    };

};

1;
