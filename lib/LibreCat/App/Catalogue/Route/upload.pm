package LibreCat::App::Catalogue::Route::upload;

=head1 NAME LibreCat::App::Catalogue::Route::upload

Route handler for uploading files.

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat::App::Catalogue::Controller::File qw/upload_temp_file remove_temp_file/;
use Dancer ':syntax';

=head1 REST METHODS

All methods for file uploads

=cut

=head2 POST /librecat/upload?file=[FILE_UPLOAD]

Needs a login session. Any login can upload files. These files are given
a random unique identifier. When these files ids are attached to the publication
record, they will be moved to a permanent storage when saving the file.

Upload a File to temporary storage. Returns a JSON document containing
the upload details and default metadata on success or a JSON error
document on failure:

  # success
  {
    'file_name'    => '183589768.pdf',
    'file_size'    => '1174241',
    'tempid'       => 'sK_QXY7vmd',
    'content_type' => 'application/pdf',
    'access_level' => 'open_access',
    'rac_email'    => 'me@example.com' # in case access_level is rac
    'relation'     => 'main_file',
    'creator'      => 'einstein',
    'date_created' => '2016-05-30T11:20:34Z',
    'date_updated' => '2016-05-30T11:20:34Z',
    'success'      => 1
  }

  # failure
  {
    success        => 0,
    error_message  => 'Sorry! The file upload failed.'
  }

=cut

post '/librecat/upload' => sub {
    my $file      = request->upload('file');
    my $creator   = session->{user};

    # Upload the data and add some metadata on the origin of the request...
    my $res       = upload_temp_file($file, $creator, {
        address      => request->address,
        referer      => request->referer,
    });

    defined $res->{error_message} ? status(500) : status(200);

    return to_json($res);
};

=head2 DEL /librecat/upload/ID

Request the deletion of a temporary file upload (when available). This command
will not remove files from permanent storage. To do this, the complete record
needs to be saved.

=cut

del '/librecat/upload/:id' => sub {
    my $fileid    = param("id");
    my $creator   = session->{user};

    my $res       = remove_temp_file($fileid, $creator, {
        address      => request->address,
        referer      => request->referer,
    });

    ($res->{success} == 1) ? status(200) : status(500);

    return to_json($res);
};

1;
