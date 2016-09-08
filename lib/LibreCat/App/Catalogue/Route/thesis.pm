package LibreCat::App::Catalogue::Route::thesis;

=head1 NAME LibreCat::App::Catalogue::Route::thesis

Route handler for uploading Bielefeld thesis.

=cut

use Catmandu::Sane;
use Catmandu qw/export_to_string/;
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::File qw/upload_temp_file/;
use Dancer ':syntax';
use Dancer::Plugin::Email;
use Try::Tiny;
use Dancer::Plugin::Auth::Tiny;

post '/librecat/thesesupload' => sub {
    my $file      = request->upload('file');
    my $creator   = session->{user} ? session->{user} : "pubtheses";
    my $temp_file = upload_temp_file($file, $creator);
    return to_json($temp_file);
};

post '/librecat/thesesupload/submit' => sub {
    my $submit_or_cancel = params->{submit_or_cancel} || "Cancel";

    if ($submit_or_cancel eq "Submit") {
        my $id  = h->new_record('publication');
        my $now = h->now();

        my $record = {
            _id       => $id,
            status    => "new",
            accept    => 1,
            title     => params->{title},
            type      => params->{type},
            email     => params->{email},
            publisher => "Universität Bielefeld",
            place     => "Bielefeld",
            ddc       => [params->{ddc}],
            author    => [
                {
                    first_name => params->{'author.first_name'},
                    last_name  => params->{'author.last_name'},
                    full_name  => params->{'author.last_name'} . ", "
                        . params->{'author.first_name'},
                }
            ],
            year => substr($now, 0, 4),
            abstract => [{lang => "eng", text => params->{'abstract'},}],
            cc_license => params->{'cc_license'},
            file       => [
                {
                    access_level => 'open_access',
                    content_type => params->{content_type},
                    file_name    => params->{file_name},
                    file_size    => params->{file_size},
                    open_access  => 1,
                    creator      => 'pubtheses',
                    relation     => 'main_file',
                    tempid       => params->{tempid},
                }
            ]
        };

        my $response = h->update_record('publication', $record);

        # Send mail to librarian
        my $mail_body = export_to_string(
            {
                title  => $record->{title},
                author => $record->{author}->[0]->{full_name},
                _id    => $id,
                host   => h->config->{host},
            },
            'Template',
            template => 'views/email/new_thesis.tt'
        );

        try {
            email {
                to       => h->config->{thesis}->{to},
                subject  => h->config->{thesis}->{subject},
                body     => $mail_body,
                reply_to => $record->{email},
            };
        }
        catch {
            error "Could not send email: $_";
        }
    }

    redirect '/pubtheses?success=1';
};

1;
