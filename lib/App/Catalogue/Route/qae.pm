package App::Catalogue::Route::qae;

=head1 NAME App::Catalogue::Route::qae

Route handler for uploading the Quick and Easy upload.

=cut

use Catmandu::Sane;
use App::Helper;
use App::Catalogue::Controller::File qw/update_file/;
use Dancer ':syntax';
use Dancer::FileUtils qw/path dirname/;
use Try::Tiny;
use File::Copy;
use Carp;
use Dancer::Plugin::Auth::Tiny;
use Crypt::Digest::MD5;
use Encode qw(encode_utf8);

post '/librecat/upload/qae/submit' => needs login => sub {
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

    my $response = h->update_record('publication', $record);

  } else {
    my $path = path( h->config->{filestore}->{tmp_dir}, params->{tempid}, $file_name);
    unlink $path;
  }

  redirect request->{referer};
};

1;
