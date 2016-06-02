package App::Catalogue::Route::thesis;

=head1 NAME App::Catalogue::Route::thesis

Route handler for uploading Bielefeld thesis.

=cut

use Catmandu::Sane;
use Catmandu qw/export_to_string/;
use App::Helper;
use App::Catalogue::Controller::File qw/update_file upload_temp_file/;
use Dancer ':syntax';
use Dancer::FileUtils qw/path dirname/;
use Dancer::Plugin::Email;
use Try::Tiny;
use File::Copy;
use Carp;
use Dancer::Plugin::Auth::Tiny;
use Crypt::Digest::MD5;
use Encode qw(encode_utf8);

post '/librecat/thesesupload' => sub {
    my $file    = request->upload('file');
    my $creator = session->{user} ? session->{user} : "pubtheses";
    my $temp_file = upload_temp_file($file,$creator);
    return to_json($temp_file);
};

post '/librecat/thesesupload/submit' => sub {
  my $submit_or_cancel = params->{submit_or_cancel} || "Cancel";
  my $file_name = params->{file_name};
  my $file_data;

  if($submit_or_cancel eq "Submit"){
      my $temp_file = path(h->config->{filestore}->{tmp_dir}, params->{tempid}, $file_name);
      if(system "-e $temp_file"){
          my $id = h->new_record('publication');
          my $file_id = h->new_record('publication');
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
              title => params->{title},
              type => params->{type},
              email => params->{email},
              publisher => "Universität Bielefeld",
              place => "Bielefeld",
              ddc => [params->{ddc}],
              department => [{name => "Universitätsbibliothek", _id => "10085", tree => [{name => "Universitätsbibliothek", id => "10085"}]}],
              author => [{
                  first_name => params->{'author.first_name'},
                  last_name => params->{'author.last_name'},
                  full_name => params->{'author.last_name'} . ", " . params->{'author.first_name'},
              }],
              year => substr($now, 0, 4),
              abstract => [{
                  lang => "eng",
                  text => params->{'abstract'},
              }],
              cc_license => params->{'cc_license'},
          };
          push @{$record->{file}}, to_json({
              file_name => $file_name,
              file_id => $file_id,
              tempid => $file_id,
              access_level => "open_access",
              open_access => 1,
              date_updated => $now,
              date_created => $now,
              creator => "pubtheses",
              open_access => 1,
              relation => "main_file",
              checksum => $digest,
          });
          
          my $response = h->update_record('publication', $record);
          
          #send mail to librarian
          my $mail_body = export_to_string({
              title => $record->{title},
              author => $record->{author}->[0]->{full_name},
              _id => $id,
              host => h->config->{host},
              },
              'Template',
              template => 'views/email/new_thesis.tt'
          );
          
          try {
              email {
                  to => h->config->{thesis}->{to},
                  subject => h->config->{thesis}->{subject},
                  body => $mail_body,
                  reply_to => $record->{email},
              };
          } catch {
              error "Could not send email: $_";
          }
      }
      else {
          redirect '/pubtheses';
      }

  } else {
    my $path = path( h->config->{filestore}->{tmp_dir}, params->{tempid}, $file_name);
    unlink $path;
  }
  
  redirect '/pubtheses?success=1';

};

1;
