package App::Search::Route::thumbnail;

=head1 NAME

  App::Search::Route::thumbnail - deliver thumbnail to the splash page.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax :script/;

=head2 AJAX /thumbnail/:id/:file_name

  Get a thumbnail image for a given id and file name.

=cut
ajax '/thumbnail/:id/:file_name' => sub {
    my $id = params->{id};
    my $filename = params->{file_name};

    if (my $pub = h->publications->get($id)) {
        return status 404 unless $pub->{submissionStatus} eq 'public'; # check if it's public
        my $files = $pub->{file} || return status 404;

        for my $file (@$files) {
            if ($file->{fileName} eq $filename) { # found the file
                if ($file->{accessLevel} eq 'admin') {
                    return status 404;
                }
                if ($file->{accessLevel} eq 'lu') { # check if ip is in range
                    return status 401 unless request->address =~ config->{ip_range};
                }
                my $path = thumbnail_path($id, $file) // return status 404; # is there a thumbnail?
                # send the file
                send_file $path,
                    system_path  => 1,
                    content_type => 'image/png';
            }
        }
    }
    status 404;
};

1;
