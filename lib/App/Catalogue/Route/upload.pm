package App::Catalogue::Route::upload;

=head1 NAME App::Catalogue::Route::upload

    Route handler for uploading files.

=cut

use Catmandu::Sane;
use App::Helper;
use App::Catalogue::Controller::Publication qw/update_publication new_publication/;
use App::Catalogue::Controller::File qw/delete_file/;
use Dancer ':syntax';
use Dancer::FileUtils qw/path dirname/;
use File::Copy;
use Carp;
use Dancer::Plugin::Auth::Tiny;
use Digest::MD5 qw/md5_hex/;

=head1 PREFIX /myPUB

    Section, where all uploads are handled.

=cut
prefix '/myPUB' => sub {

  # receives file and places it in tmp
  # copies it to file with real filename (instead of tmp name)
  # returns json with filename (TODO: or status msg)
  post '/upload' => needs login =>  sub {
      my $file    = request->upload('file');
      my $file_data;

      if($file){
      	  my $now = h->now;
      	  my $tempid = $file->{tempname};
      	  $tempid =~ s/.*\/([^\/\.]*)\..*/$1/g;
          $file_data = {
            success => 1,
            file_name => $file->{filename},
            creator => session->{user},
            file_size => $file->{size},
            date_updated => $now,
            date_created => $now,
            access_level => "openAccess",
            content_type => $file->{headers}->{"Content-Type"},
            relation => "main_file",
            year_last_uploaded => substr($now,0,4),
            tempname => $file->{tempname},
            tempid => $tempid,
          };
          my $filedir = path(h->config->{upload_dir}, $tempid);
          mkdir $filedir || croak "Could not create dir $filedir: $!";
          my $filepath = path(h->config->{upload_dir}, $tempid, $file->{filename});
      	  copy($file->{tempname}, $filepath);

      	  my $ctx = Digest::MD5->new;
      	  $ctx->addfile($file->file_handle());
      	  my $digest = $ctx->md5_hex;
      	  $file_data->{checksum} = $digest;

      	  $file_data->{file_json} = to_json($file_data);
      	  my $status = unlink $file->{tempname};
      }
      else{
      	$file_data = {success => 0, error_message => 'Sorry! The file upload failed.'}
      }

      return to_json($file_data);
  };

  post '/upload/qae/submit' => needs login => sub {
    my $submit_or_cancel = params->{submit_or_cancel} || "Cancel";
    my $file_name = params->{file_name};
    my $file_data;

    if($submit_or_cancel eq "Submit"){
      my $id = new_publication();
      my $file_id = new_publication();
      my $person = h->getPerson(session->{personNumber});
      my $now = h->now();
      $file_data->{saved} = 1;
      my $record = {
        _id => $id,
        status => "new",
        accept => 1,
        title => "New Quick And Easy Publication - Will be edited by PUB-Team",
        type => "journalArticle",
        message => params->{description},
        author => [{
          first_name => $person->{first_name},
          last_name => $person->{last_name},
          full_name => $person->{full_name},
          id => session->{personNumber},
          }],
        year => substr($now, 0, 4),

      };
      push @{$record->{file}}, to_json({
        file_name => $file_name,
        file_id => $file_id,
        access_level => "openAccess",
        date_updated => $now,
        date_created => $now,
        creator => session->{user},
        open_access => 1,
        relation => "main_file",
      });
      push @{$record->{file_order}}, $file_id;

      my $path = h->get_file_path($id);
      system "mkdir -p $path" unless -d $path;
      my $result = move( path(h->config->{upload_dir}, params->{tempid}, $file_name), $path ) || die $!;

      my $response = update_publication($record);

    } else {
      my $path = path( h->config->{upload_dir}, params->{tempid}, $file_name);
      unlink $path;
    }

    redirect '/myPUB';
  };

  post '/upload/update' => needs login =>  sub {
      my $file          = request->upload('file');
      my $old_file_name = params->{old_file_name} || params->{file_name};
      my $id            = params->{id};
      my $file_id       = params->{file_id};
      my $tempid		= params->{tempid};
      my $success       = 1;

      if ($file) {
      	  my $filepath = path(h->config->{upload_dir}, $file->{filename});
      	  copy($file->{tempname}, $filepath);
      	  my $status = unlink $file->{tempname};
      }

      # then return data of updated file
      my $file_data;
      if ($success) {
          my $now = h->now;
          $file_data = {
            success => 1,
            file_name => $file ? $file->{filename} : $old_file_name,
            creator => params->{creator} || session->{user},
            file_size => $file ? $file->{size} : '',
            date_updated => $now,
            date_created => $now,
            access_level => params->{access_level} || "openAccess",
            content_type => $file ? $file->{headers}->{"Content-Type"} : '',
            title => params->{title} || '',
            description => params->{description} || '',
            request_a_copy => params->{request_a_copy} ||= 0,
            relation => params->{relation} || 'main_file',
            old_file_name => $old_file_name,
          };
          $file_data->{embargo} = params->{embargo} if params->{embargo};
          $file_data->{file_id} = $file_id if $file_id;
          $file_data->{tempid} = $tempid if $tempid;
          $file_data->{file_json} = to_json($file_data);
      }
      else {
          $file_data = {
            success => 0,
            error => "There was an error while uploading your file.",
          };
      }

      return to_json($file_data);
  };

  post '/upload/delete' => needs login => sub {
      my $pub_id = params->{id};
      my $file_name = params->{file_name};
      delete_file($pub_id, $file_name);
  };

};

1;
