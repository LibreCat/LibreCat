package App::Api::Route::Demo;

=head1 NAME

App::Catalogue::Route::Demo - REST API demonstrator for LibreCat coders

=cut

use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Plugin::Auth::Tiny;
use App::Helper;
use REST::Client;
use JSON;

Dancer::Plugin::Auth::Tiny->extend(
    role => sub {
        my ($role, $coderef) = @_;
        return sub {
            if ($role eq 'api_access' && ip_match(request->address)) {
                goto $coderef;
            }
            elsif ( session->{role} && $role eq session->{role} ) {
                goto $coderef;
            }
            else {
                return do_error('NOT_ALLOWED','access denied',404);
            }
        }
    }
);

set serializer => 'JSON';

sub ip_match {
    my $ip = shift;
    my $access    = h->config->{filestore_api}->{access} // {};
    my $ip_ranges = $access->{ip_ranges} // [];

    for my $range (@$ip_ranges) {
        $range =~ s{\*}{\\w+}g;
        return 1 if ($ip =~ /^$range$/);
    } 

    return 0;
}

sub do_error {
    my ($code,$msg,$http_code) = @_;
    $http_code = 500 unless defined $http_code;
    send_error({ code => , $code , error => $msg },$http_code);
}

prefix '/librecat/api' => sub {
=head2 GET /librecat/api

Return a HTML page with demonstrators for file upload, file access , etc.

=cut

    get '/' => needs role => 'api_access' => sub {
        template 'api/filestore';
    };

    post '/' => needs role => 'api_access' => sub {
        my $action = param "action";
        my $res = {};
        
        if (0) {}
        elsif ($action eq 'upload') {
            my $file      = request->upload('file');
            my $key       = param('key');
            my $filename  = $file->{filename};
            my $filepath  = $file->{tempname};

            if (defined $key && defined $filepath) {
                do_file_upload($key,$filename,$filepath);
                do_create_thumbnail($key,$filename);

                $res->{upload_message} = "done";
            }
            else {
                $res->{upload_message} = "Need a key and a file";
            }
        }

        template 'api/filestore' , $res;
    };
};

sub do_file_upload {
    my ($key,$filename,$filepath) = @_;
    my $uploader_package = h->config->{filestore_uploader}->{package};
    my $uploader_options = h->config->{filestore_uploader}->{options};

    my $pkg = Catmandu::Util::require_package($uploader_package);
    my $worker = $pkg->new(%$uploader_options);

    $worker->do_work($key,$filename,$filepath);
}

sub do_create_thumbnail {
    my ($key,$filename) = @_;
    my $thumbnailer_package = h->config->{accessstore_thumbnailer}->{package};
    my $thumbnailer_options = h->config->{accessstore_thumbnailer}->{options};

    my $pkg = Catmandu::Util::require_package($thumbnailer_package);
    my $worker = $pkg->new(%$thumbnailer_options);

    $worker->do_work($key,$filename);
}

1;