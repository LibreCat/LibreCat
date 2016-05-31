package App::Catalogue::Route::upload;

=head1 NAME App::Catalogue::Route::upload

Route handler for uploading files.

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use App::Helper;
use App::Catalogue::Controller::File qw/update_file delete_file upload_temp_file/;
use Dancer ':syntax';
use Dancer::Plugin::Auth::Tiny;

=head1 PREFIX /librecat

Section, where all uploads are handled.

=cut

=head2 POST /librecat/upload?file=[FILE_UPLOAD]

Needs a login session.

Upload a File to temporary storage. Returns a JSON document containing
the upload details on success or a JSON error document on failure:

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
  }

  # failure
  {
    success        => 0,
    error_message  => 'Sorry! The file upload failed.'
  }

=cut
post '/librecat/upload' => needs login =>  sub {
    my $file    = request->upload('file');
    my $creator = session->{user};
    return to_json( upload_temp_file($file,$creator) );
};

=head2 POST /librecat/upload/update?%PARAMS

With %params:

 id
 file_id
 title
 access_level
 request_a_copy
 embargo
 description
 relation

Return a JSON document with updated file metadata:

  {
    'file_id'        => '13',
    'access_level'   => 'open_access',
    'open_access'    => 1,
    'relation'       => 'main_file',
    'title'          => 'blabla',
    'description'    => 'test' ,
    'request_a_copy' => '0' ,
    'embargo'        => '' ,
  }

=cut
post '/librecat/upload/update' => needs login =>  sub {
    my $key           = params->{id};
    my $file_id       = params->{file_id};

    my @important_fields  = qw(
            file_id file_order file_name file_size content_type 
            creator date_created
            );
    
    my @changeable_fields = qw(
            title description access_level request_a_copy 
            open_access embargo relation
            );

    my $file_data = {};

    for my $name (@changeable_fields) {
        $file_data->{$name} = params->{$name};
    }

    for my $name (@important_fields) {
        $file_data->{$name} = params->{$name} if is_string(params->{$name});
    }

    $file_data->{tempid}      = params->{tempid} if is_string(params->{tempid});
    $file_data->{open_access} = params->{access_level} && params->{access_level} eq "open_access" ? 1 : 0;

    return to_json($file_data);
};

1;
