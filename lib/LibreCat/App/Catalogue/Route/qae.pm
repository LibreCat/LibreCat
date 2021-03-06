package LibreCat::App::Catalogue::Route::qae;

=head1 NAME LibreCat::App::Catalogue::Route::qae

Route handler for uploading the Quick and Easy upload.

=cut

use Catmandu::Sane;
use LibreCat qw(publication department timestamp);
use LibreCat::App::Helper;
use Dancer ':syntax';

=head2 GET /librecat/upload/qae/submit

Returns again to the add record page

=cut
get '/librecat/upload/qae/submit' => sub {
    # Required route for 'return_url' mechanism...
    redirect h->uri_for('/librecat/record/new');
};

=head2 POST /librecat/upload/qae/submit

Returns a form with imported data.

=cut
post '/librecat/upload/qae/submit' => sub {
    my $submit_or_cancel = params->{submit_or_cancel} || "Cancel";

    if ($submit_or_cancel eq "Submit" and params->{has_accepted_license}) {
        my $id = publication->generate_id;
        my $person = h->get_person(params->{delegate} || session->{user_id});
        my $department = department->get(params->{reviewer})
            if params->{reviewer};
        my $now = timestamp;

        my $record = {
            _id    => $id,
            status => "new"
            ,    # new is the status of records not checked by users/reviewers
            has_accepted_license => 1,
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
            year       => substr($now, 0, 4),
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
                    relation     => 'main_file',
                }
            ]
        };

        # Use config/hooks.yml to register functions
        # that should run before/after uploading QAE publications
        h->hook('qae-new')->fix_around(
            $record,
            sub {
                publication->add($record);
            }
        );

        return template "backend/add_new",
            {
            ok       => "Imported 1 record(s) from dropzone",
            imported => [$record]
            };
    }

    redirect h->uri_for('/librecat/add/new');
};

1;
