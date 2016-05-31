package App::Catalogue::Route::upload;

=head1 NAME App::Catalogue::Route::upload

Route handler for uploading files.

=cut

use Catmandu::Sane;
use Catmandu qw/export_to_string/;
use App::Helper;
use App::Catalogue::Controller::File qw/update_file delete_file upload_temp_file create_file_metadata/;
use Dancer ':syntax';
use Dancer::FileUtils qw/path dirname/;
use Dancer::Plugin::Email;
use Try::Tiny;
use File::Copy;
use Carp;
use Dancer::Plugin::Auth::Tiny;
use Crypt::Digest::MD5;
use Encode qw(encode_utf8);

=head1 PREFIX /librecat

Section, where all uploads are handled.

=cut

prefix '/librecat' => sub {

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
  post '/upload' => needs login =>  sub {
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
 file_name

=cut
  post '/upload/update' => needs login =>  sub {
      my $key           = params->{id};
      my $file_id       = params->{file_id};

      return to_json( 
          create_file_metadata(
              $key,
              $file_id,
              file_name      => params->{file_name},
              access_level   => params->{access_level},
              title          => params->{title},
              description    => params->{description},
              request_a_copy => params->{request_a_copy},
              relation       => params->{relation},
              embargo        => params->{embargo}, 
              tempid         => params->{tempid},
          ) 
      );
  };

  post '/upload/delete' => needs login => sub {
      my $pub_id = params->{id};
      my $file_name = params->{file_name};
      delete_file($pub_id, $file_name);
  };

  post '/upload/qae/submit' => needs login => sub {
    my $submit_or_cancel = params->{submit_or_cancel} || "Cancel";
    my $file_name = params->{file_name};
    my $file_data;

    if($submit_or_cancel eq "Submit"){
      my $id = h->new_record('publication');
      my $file_id = h->new_record('publication');
      my $person = h->get_person(params->{delegate} || session->{personNumber});
      my $department = h->get_department(params->{reviewer}) if params->{reviewer};
      my $now = h->now();
      $file_data->{saved} = 1;

      my $path = path(h->config->{filestore}->{tmp_dir}, params->{tempid}, $file_name);
      update_file($id,$file_name,$path);

      my $d = Crypt::Digest::MD5->new;
      $d->addfile(encode_utf8($path));
      my $digest = $d->hexdigest; # hexadecimal form

      my $record = {
        _id => $id,
        status => "new",
        accept => 1,
        title => "New Quick And Easy Publication - Will be edited by PUB-Team",
        publication => "Quick And Easy Journal Title",
        type => "journalArticle",
        message => params->{description},
        author => [{
          first_name => $person->{first_name},
          last_name => $person->{last_name},
          full_name => $person->{full_name},
          id => $person->{_id},
          }],
        year => substr($now, 0, 4),
        department => $department || $person->{department},
        creator => {id => session->{personNumber}, login => session->{user}},
      };

      push @{$record->{file}}, to_json({
        file_name => $file_name,
        file_id => $file_id,
        tempid => $file_id,
        access_level => "open_access",
        open_access => 1,
        date_updated => $now,
        date_created => $now,
        creator => session->{user},
        open_access => 1,
        relation => "main_file",
        checksum => $digest,
      });
      push @{$record->{file_order}}, $file_id;

      my $response = h->update_record('publication', $record);

    } else {
      my $path = path( h->config->{filestore}->{tmp_dir}, params->{tempid}, $file_name);
      unlink $path;
    }

    redirect request->{referer};
  };


};

1;
