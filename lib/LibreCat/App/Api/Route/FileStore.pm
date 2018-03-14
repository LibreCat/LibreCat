package LibreCat::App::Api::Route::FileStore;

=head1 NAME

LibreCat::App::Catalogue::Route::FileStore - REST API for managing the repository backend storage

=cut

use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Plugin::StreamData;
use LibreCat::App::Helper;
use IO::File;
use namespace::clean;

set serializer => 'JSON';

sub do_error {
    my ($code, $msg, $http_code) = @_;
    $http_code = 500 unless defined $http_code;
    send_error({code =>, $code, error => $msg}, $http_code);
}

prefix '/librecat/api' => sub {

=head2 GET /librecat/api/filestore

Return a text stream of all container identifier in the repository.
E.g.

    $ curl -H "Content-Type: application/json" -X GET  "http://localhost:5001/librecat/api/filestore"
    000000122
    000000006
    000000010
    000000121
    000000001
    000000008

=cut

    get '/filestore' => sub {
        my $index = h->get_file_store()->index;

        send_file(
            \"dummy",    # anything, as long as it's a scalar-ref
            streaming => 1,    # enable streaming
            callbacks => {
                override => sub {
                    my ($respond, $response) = @_;
                    my $http_status_code = 200;

              # Tech.note: This is a hash of HTTP header/values, but the
              #            function below requires an even-numbered array-ref.
                    my @http_headers = (
                        'Content-Type' => 'text/plain',
                        'Cache-Control' =>
                            'no-store, no-cache, must-revalidate, max-age=0',
                        'Pragma' => 'no-cache'
                    );

         # Send the HTTP headers
         # (back to either the user or the upstream HTTP web-server front-end)
                    my $writer
                        = $respond->([$http_status_code, \@http_headers]);

                    $index->each(
                        sub {
                            my $key = shift->{_id};
                            $writer->write("$key\n");
                        }
                    );

                    $writer->close();
                },
            },
        );
    };

=head2 GET /librecat/api/filestore/:key

Return the content of a container in JSON format

E.g.

    $ curl -H "Content-Type: application/json" -X GET "http://localhost:5001/librecat/api/filestore/000000008"
    {
       "files" : [
          {
             "md5" : "",
             "key" : "rprogramming.pdf",
             "modified" : 1457099958,
             "size" : 10930639
          }
       ],
       "modified" : 1457102844,
       "created" : 1457102844,
       "key" : "000000008"
    }

=cut

    get '/filestore/:key' => sub {
        my $key   = param('key');
        my $store = h->get_file_store();

        content_type 'application/json';

        if ($store->index->exists($key)) {
            my $files = $store->index->files($key);

            my $doc = {key => $key,};

            $files->each(
                sub {
                    my $file     = shift;
                    my $key      = $file->{_id};
                    my $size     = $file->{size};
                    my $md5      = $file->{md5};
                    my $modified = $file->{modified};
                    my $created  = $file->{created};

                    push @{$doc->{files}},
                        {
                        key      => $key,
                        size     => $size,
                        md5      => $md5,
                        modified => $modified,
                        created  => $created
                        };
                }
            );

            return $doc;
        }
        else {
            return do_error('NOT_FOUND', 'no such container', 404);
        }
    };

=head2 GET /librecat/api/filestore/:key/:filename

Return the binary content of a file in a container

E.g.

    $ curl -H "Content-Type: application/json" -X GET "http://localhost:5001/librecat/api/filestore/000000008/rprogramming.pdf"
    <... binary data ...>

=cut

    get '/filestore/:key/:filename' => sub {
        my $key      = param('key');
        my $filename = param('filename');

        my $store = h->get_file_store();

        do_error('NOT_FOUND', 'no such container', 404)
            unless $store->index->exists($key);

        my $files = $store->index->files($key);
        my $file  = $files->get($filename);

        do_error('NOT_FOUND', 'no such file', 404) unless $file;

        send_file(
            \"dummy",    # anything, as long as it's a scalar-ref
            streaming => 1,    # enable streaming
            callbacks => {
                override => sub {
                    my ($respond, $response) = @_;
                    my $content_type = $file->{content_type};

                    my $http_status_code = 200;

              # Tech.note: This is a hash of HTTP header/values, but the
              #            function below requires an even-numbered array-ref.
                    my @http_headers = (
                        'Content-Type' => $content_type,
                        'Cache-Control' =>
                            'no-store, no-cache, must-revalidate, max-age=0',
                        'Pragma' => 'no-cache'
                    );

         # Send the HTTP headers
         # (back to either the user or the upstream HTTP web-server front-end)
                    my $writer
                        = $respond->([$http_status_code, \@http_headers]);

                    $files->stream($writer, $file);
                },
            },
        );
    };

=head2 DEL /librecat/api/filestore/:key

Delete a container from the repository

E.g.

    $ curl -H "Content-Type: application/json" -X DELETE "http://localhost:5001/librecat/api/filestore/000000008"
    { "ok": "1"}

=cut

    del '/filestore/:key' => sub {
        my $key = param('key');

        content_type 'application/json';

        my $store = h->get_file_store();

        if ($store->index->exits($key)) {
            $store->index->delete($key);
            return {ok => 1};
        }
        else {
            return do_error('NOT_FOUND', 'no such container', 404);
        }
    };

=head2 DEL /librecat/api/filestore/:key/:filename

Delete a file in a container from the repository

E.g.

    $ curl -H "Content-Type: application/json" -X DELETE "http://localhost:5001/librecat/api/filestore/000000008/rprogramming.pdf"
    { "ok": "1"}

=cut

    del '/filestore/:key/:filename' => sub {
        my $key      = param('key');
        my $filename = param('filename');

        content_type 'application/json';

        my $store = h->get_file_store();

        if ($store->index->exists($key)) {
            my $files = $store->index->files($key);

            my $file = $files->get($filename);

            if (defined $file) {
                $files->delete($filename);
                return {ok => 1};
            }
            else {
                return do_error('NOT_FOUND', 'no such file', 404);
            }
        }
        else {
            return do_error('NOT_FOUND', 'no such container', 404);
        }
    };

=head2 POST /librecat/api/filestore/:key

Add a file to a container in the repository

E.g.

    $ curl -H "Content-Type: application/json" -F file=@rpogramming.pdf -X POST  "http://localhost:5001/librecat/api/filestore/000000008"
    { "ok": "1"}

=cut

    post '/filestore/:key' => sub {
        my $key = param('key');

        content_type 'application/json';

        my $store = h->get_file_store();

        unless ($store->index->exists($key)) {
            $store->index->add($key);
        }

        my $files = $store->index->files($key);

        my $file = request->upload('file');

        unless ($file) {
            return do_error('ILLEGAL_INPUT', 'need a file', 400);
        }

        $files->add(IO::File->new($file->{tempname}), $file->{filename});

        return {ok => 1};
    };

=head2 GET /librecat/api/access/:key/:filename/thumbnail

Return the binary thumbail content of a file in a container

E.g.

    $ curl -H "Content-Type: application/json" -X GET "http://localhost:5001/librecat/api/access/000000008/rprogramming.pdf/thumbnail"
    <... binary data ...>

=cut

    get '/access/:key/:filename/thumbnail' => sub {
        my $key = param('key');

   # For now stay backwards compatible and keep one thumbnail per container...
        my $filename = 'thumbnail.png';

        my $store = h->get_access_store();

        return do_error('NOT_FOUND', 'no thumbnails for this key', 404)
            unless $store->index->exists($key);

        my $files = $store->index->files($key);

        my $file = $files->get($filename);

        return Dancer::send_file(
            'public/images/thumbnail_dummy.png',
            system_path => 1,
            filename    => 'thumbnail_dummy.png'
        ) unless $file;

        send_file(
            \"dummy",    # anything, as long as it's a scalar-ref
            streaming => 1,    # enable streaming
            callbacks => {
                override => sub {
                    my ($respond, $response) = @_;
                    my $content_type = $file->{content_type};

                    my $http_status_code = 200;

              # Tech.note: This is a hash of HTTP header/values, but the
              #            function below requires an even-numbered array-ref.
                    my @http_headers = (
                        'Content-Type' => $content_type,
                        'Cache-Control' =>
                            'no-store, no-cache, must-revalidate, max-age=0',
                        'Pragma' => 'no-cache'
                    );

         # Send the HTTP headers
         # (back to either the user or the upstream HTTP web-server front-end)
                    my $writer
                        = $respond->([$http_status_code, \@http_headers]);

                    $files->stream($writer, $file);
                },
            },
        );
    };

=head2 POST /librecat/api/access/:key/:filename/thumbnail

Create a thumbail for a file in a container

E.g.

    $ curl -H "Content-Type: application/json" -X POST "http://localhost:5001/librecat/api/access/000000008/rprogramming.pdf/thumbnail"

=cut

    post '/access/:key/:filename/thumbnail' => sub {
        my $key      = param('key');
        my $filename = param('filename');

        my $thumbnailer_package
            = h->config->{filestore}->{access_thumbnailer}->{package};
        my $thumbnailer_options
            = h->config->{filestore}->{access_thumbnailer}->{options};

        my $pkg = Catmandu::Util::require_package($thumbnailer_package,
            'LibreCat::Worker');
        my $worker = $pkg->new(%$thumbnailer_options);

        my $response = $worker->work({key => $key, filename => $filename,});

        $response;
    };

=head2 DEL /librecat/api/access/:key/:filename/thumbnail

Delete a thumbnail in a container

E.g.

    $ curl -H "Content-Type: application/json" -X DELETE "http://localhost:5001/librecat/api/access/000000008/rprogramming.pdf/thumbnail"
    { "ok": "1"}

=cut

    del '/access/:key/:filename/thumbnail' => sub {
        my $key = param('key');

        my $thumbnailer_package
            = h->config->{filestore}->{access_thumbnailer}->{package};
        my $thumbnailer_options
            = h->config->{filestore}->{access_thumbnailer}->{options};

        my $pkg = Catmandu::Util::require_package($thumbnailer_package,
            'LibreCat::Worker');
        my $worker = $pkg->new(%$thumbnailer_options);

        my $response = $worker->work({key => $key, delete => 1});

        $response;
    };
};

1;
