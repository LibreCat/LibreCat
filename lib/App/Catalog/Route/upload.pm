package App::Catalog::Route::upload;

=head1 NAME App::Catalog::Route::upload

    Route handler for uploading files.

=cut

use Catmandu::Sane;
use App::Catalog::Helper;
use App::Catalog::Controller::Publication qw/update_publicaton/;
use Dancer ':syntax';
use Dancer::FileUtils qw/path dirname/;
use File::Copy;
use Dancer::Plugin::Auth::Tiny;

=head1 PREFIX /myPUB

    Section, where all uploads are handled.

=cut
prefix => '/myPUB' => sub {

  post '/upload' => sub {
      my $file    = request->upload('file');
      my $id = params->{_id};

      my $file_id = new_publication();
      my $path    = path( h->config->{upload_dir}, "$id", $file->{filename} );
      my $dir     = dirname($path);
      mkdir $dir unless -e $dir;
      my $success = $file->copy_to($path);

      my $file_data;
      if ($success) {
          $file_data = {
            success => 1,
            file_name => $file->{filename},
            creator => session->{user},
            file_size => $file->{size},
            file_id => $file_id,
            date_updated => h->now,
            acces_level => "openAccess",
            content_type => $file->{headers}->{"Content-Type"},
            relation => "main_file",
            year_last_uploaded => substr(h->now,0,4);
          };
      }
      else {
          $file_data = {
            success => 0,
            error => "There was an error while uploading your file.",
          }
      }

      return to_json($file_data);
  };

  post '/upload/qai' => sub {
      my $file    = request->upload('file');

      my $file_data;
      $file_data->{tempname} = $file->{tempname};
      $file_data->{filename} = $file->{filename};
      copy( $file->{tempname}, path(h->config->{upload_dir}, $file->{filename}) );

      return to_json($file_data);
  };

  post '/upload/qai_submit' => sub {
    my $tmp_file = params->{tmp_file};
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
        title => "New Quick And Easy Publication - Please edit",
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
        access_level => openAccess,
        date_updated => $now,
        date_created => $now,
        creator => sesson->{user},
        open_access => 1,
        relation => main_file,
      });
      push @{$record->{file_order}}, $file_id;

      my $path = path( h->config->{upload_dir}, $id, $file_name );
      my $dir = dirname($path);
      mkdir $dir unless -e $dir;
      move( path(h->config->{upload_dir}, $file_name), $path );

      my $response = update_publication($record);

    } else { # this never happens!?
      my $path = path( h->config->{upload_dir}, $file_name);
      unlink $path;
    }

    redirect '/myPUB';
  };

post '/upload/update' => sub {
    my $file          = request->upload('file');
    my $old_file_name = params->{old_file_name};
    my $id            = params->{id};
    my $file_id       = params->{file_id};
    my $success       = 1;

    if ($file) {

        # first delete old file from dir
        my $file_path = path(h->config->{upload_dir},$id, $old_file_name);
        unlink $file_path if -e $file_path;

        # then copy new file to dir
        my $path = path( h->config->{upload_dir}, $id, $file->{filename} );
        my $dir = path(h->config->{upload_dir}, $id);
        mkdir $dir unless -e $dir;
        $success = $file->copy_to($path);

    }

    # then return data of updated file
    my $file_data;
    if ($success) {
        my $now = h->now;
        $file_data = {
          success => 1,
          file_name => $file ? $file->{filename} : $old_file_name,
          creator => session->{user},
          file_size => $file ? $file->{size} : '',
          file_id => $file_id,
          date_updated => $now,
          date_created => $now,
          access_level => params->{access_level} || "openAccess",
          content_type => $file ? $file->{headers}->{"Content-Type"} : '',
          file_title => params->{file_title} || '',
          description => params->{description || '',
          request_a_copy => params->{request_a_copy} ||= 0,
          embargo => params->{embargo} || '',
          relation => params->{relation} || 'main_file',
          old_file_name => $old_file_name,
#          language => params->{language},
        };

        #do we need this?
        #$file_data->{open_access} = ( params->{access_level}
        #        and params->{access_level} eq "openAccess" ) ? 1 : 0;

        # IMHO, this part is not necessary.
        my $record = h->publication->get($id);
        foreach my $recfile ( @{ $record->{file} } ) {
            if ( $recfile->{file_id} eq $file_data->{file_id} ) {
                $file_data->{year_last_uploaded}
                    = $recfile->{year_last_uploaded};
                $file_data->{file_size} = $recfile->{file_size}
                    if $file_data->{file_size} eq "";
                $file_data->{content_type}
                    = (     $file_data->{content_type} eq ""
                        and $recfile->{content_type} )
                    ? $recfile->{content_type}
                    : "";
                $file_data->{date_created} = $recfile->{date_created};
                if ( $file_data->{access_level} eq "openAccess" ) {
                    $file_data->{open_access} = 1;
                    $file_data->{embargo}     = "";
                }
                else {
                    $file_data->{open_access} = 0;
                }

                $recfile = ();
                $recfile = $file_data;
                delete $recfile->{file_json};
                delete $recfile->{success};
                delete $recfile->{old_file_name};
            }
        }

        $record->{request_a_copy} = $file_data->{request_a_copy};

        h->publication->add($record);
        h->publication->commit;
    }
    else {
        $file_data = {
          success => 0,
          error => "There was an error while uploading your file.",
        };
    }

    return to_json($file_data);
};

  post '/upload/delete' => sub {
      my $dir = path(h->config->{upload_dir}, params->{id}, params->{filename});
      my $status = rmdir $dir if -e $dir || 0;

      template 'error', { error => "Error: could not delete files" } if $status;
  };

};

1;
