package LibreCat::App::Catalogue::Route::qae;

=head1 NAME LibreCat::App::Catalogue::Route::qae

Route handler for uploading the Quick and Easy upload.

=cut

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer ':syntax';

post '/librecat/upload/qae/submit' => sub {
    my $submit_or_cancel = params->{submit_or_cancel} || "Cancel";

    if ($submit_or_cancel eq "Submit") {
        my $id = h->new_record('publication');
        my $person = h->get_person(params->{delegate} || session->{user_id});
        my $department = h->get_department(params->{reviewer})
            if params->{reviewer};
        my $now = h->now();

        my $record = {
            _id    => $id,
            status => "new"
            ,    # new is the status of records not checked by users/reviewers
            accept      => 1,
            title       => h->loc('add_new.qae_title'),
            publication => "Quick And Easy Journal Title",
            type        => "journal_article",
            message     => params->{description},
            author      => [
                {
                    first_name => $person->{first_name},
                    last_name  => $person->{last_name},
                    full_name  => $person->{full_name},
                    id         => $person->{_id},
                }
            ],
            year => substr($now, 0, 4),
            department => $department || $person->{department},
            creator => {id => session->{user_id}, login => session->{user}},
            user_id => session->{user_id},
            file    => [
                {
                    # Required for managing the upload
                    file_name => params->{file_name},
                    tempid    => params->{tempid},

                    # Extra metadata fields
                    access_level => 'open_access',
                    open_access  => 1,
                    relation     => 'main_file',
                }
            ]
        };

        # Use config/hooks.yml to register functions
        # that should run before/after uploading QAE publications
        LibreCat->hook('qae-new')->fix_around(
            $record,
            sub {
                my $response = h->update_record('publication', $record);
            }
        );

        return template "backend/add_new",
            {
            ok       => "Imported 1 record(s) from dropzone",
            imported => [$record]
            };
    }

    return template "backend/add_new";
};

1;
