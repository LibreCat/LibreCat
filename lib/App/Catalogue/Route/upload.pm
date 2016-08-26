package App::Catalogue::Route::upload;

=head1 NAME App::Catalogue::Route::upload

Route handler for uploading files.

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use App::Catalogue::Controller::File qw/upload_temp_file/;
use Dancer ':syntax';
use Dancer::Plugin::Auth::Tiny;

=head1 REST METHODS

All methods for file uploads

=cut

=head2 POST /librecat/upload?file=[FILE_UPLOAD]

Needs a login session.

Upload a File to temporary storage. Returns a JSON document containing
the upload details and default metadata on success or a JSON error
document on failure:

  # success
  {
    'file_name'    => '183589768.pdf',
    'file_size'    => '1174241',
    'tempid'       => 'sK_QXY7vmd',
    'tempname'     => '/tmp/sK_QXY7vmd.pdf',
    'content_type' => 'application/pdf',
    'access_level' => 'open_access',
    'open_access'  => 1,
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

post '/librecat/upload' => needs login => sub {
    my $file    = request->upload('file');
    my $creator = session->{user};
    return to_json(upload_temp_file($file, $creator));
};

1;
