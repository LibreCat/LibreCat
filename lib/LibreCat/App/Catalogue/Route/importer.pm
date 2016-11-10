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
    trim($p, 'source', 'whitespace');

    my $pub;
    my $user      = h->get_person(session->{personNumber});
    my $edit_mode = params->{edit_mode} || $user->{edit_mode} || "";

    try {
        my $id     = $p->{id};
        my $data   = request->upload('data') ? request->upload('data')->content : $p->{data};
        my $source = $p->{source};

        # Use config/hooks.yml to register functions
        # that should run before/after adding new publications
        # E.g. create a hooks to change the default fields
        state $hook = h->hook('import-new-' . $source);

        $pub = LibreCat::App::Catalogue::Controller::Importer->new(
            id     => $id // $data ,
            source => $source,
        )->fetch;

        $hook->fix_before($pub);

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

            $hook->fix_after($pub);

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
