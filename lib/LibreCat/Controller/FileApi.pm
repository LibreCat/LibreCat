package LibreCat::Controller::FileApi;

use Catmandu::Sane;
use Catmandu::Util;
# use Hash::Merge::Simple qw(merge);
use LibreCat -self;
use LibreCat::App::Helper;
use JSON::MaybeXS;
use Mojo::Base 'Mojolicious::Controller';
# use IO::File;

sub show_filestore {
    my $c = $_[0];

    my $index = $c->get_file_store->index;

    # send_file(
    #     \"dummy",    # anything, as long as it's a scalar-ref
    #     streaming => 1,    # enable streaming
    #     callbacks => {
    #         override => sub {
    #             my ($respond, $response) = @_;
    #             my $http_status_code = 200;
    #
    #           # Tech.note: This is a hash of HTTP header/values, but the
    #           #            function below requires an even-numbered array-ref.
    #             my @http_headers = (
    #                 'Content-Type' => 'text/plain',
    #                 'Cache-Control' =>
    #                     'no-store, no-cache, must-revalidate, max-age=0',
    #                 'Pragma' => 'no-cache'
    #             );
    #
    #      # Send the HTTP headers
    #      # (back to either the user or the upstream HTTP web-server front-end)
    #             my $writer = $respond->([$http_status_code, \@http_headers]);
    #
    #             $index->each(
    #                 sub {
    #                     my $key = shift->{_id};
    #                     $writer->write("$key\n");
    #                 }
    #             );
    #
    #             $writer->close;
    #         },
    #     },
    # );
}

sub show_container {
    my $c     = $_[0];
    my $key   = $c->param('key');
    my $store = $c->get_file_store;

    if ($store->index->exists($key)) {
        my $files = $store->index->files($key);

        my $doc = {key => $key};

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

        $doc->{number_of_files} = length $doc->{files} // 0;

        $c->render(json => $doc);
    }
    else {
        $c->container_not_found;
    }
}

sub show_file {
    my $c = $_[0];
    my $key      = $c->param('key');
    my $filename = $c->param('filename');

    my $store = $c->get_file_store;

    $c->container_not_found
        unless $store->index->exists($key);

    my $files = $store->index->files($key);
    my $file  = $files->get($filename);

    $c->file_not_found unless $file;

    # send_file(
    #     \"dummy",    # anything, as long as it's a scalar-ref
    #     streaming => 1,    # enable streaming
    #     callbacks => {
    #         override => sub {
    #             my ($respond, $response) = @_;
    #             my $content_type = $file->{content_type};
    #
    #             my $http_status_code = 200;
    #
    #           # Tech.note: This is a hash of HTTP header/values, but the
    #           #            function below requires an even-numbered array-ref.
    #             my @http_headers = (
    #                 'Content-Type' => $content_type,
    #                 'Cache-Control' =>
    #                     'no-store, no-cache, must-revalidate, max-age=0',
    #                 'Pragma' => 'no-cache'
    #             );
    #
    #      # Send the HTTP headers
    #      # (back to either the user or the upstream HTTP web-server front-end)
    #             my $writer = $respond->([$http_status_code, \@http_headers]);
    #
    #             $files->stream($c->io_from_plack_writer($writer), $file);
    #         },
    #     },
    # );
}

sub remove_container {
    my $c = $_[0];
    my $key = $c->param('key');

    my $store = $c->get_file_store;

    if ($store->index->exits($key)) {
        $store->index->delete($key);
        $c->render(json => {ok => 1});
    }
    else {
        $c->container_not_found;;
    }
}

sub remove_file {
    my $c = $_[0];
    my $key      = $c->param('key');
    my $filename = $c->param('filename');

    my $store = $c->get_file_store;

    if ($store->index->exists($key)) {
        my $files = $store->index->files($key);

        my $file = $files->get($filename);

        if (defined $file) {
            $files->delete($filename);
            return {ok => 1};
        }
        else {
            $c->container_not_found;
        }
    }
    else {
        $c->container_not_found;;
    }
}

sub upload_file {
    my $c = $_[0];
    my $key = $c->param('key');

    my $store = $c->get_file_store;

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
}

sub show_thumbnail {
    my $c = $_[0];
    my $key = $c->param('key');

   # For now stay backwards compatible and keep one thumbnail per container...
    my $filename = 'thumbnail.png';

    my $store = $c->get_access_store();

    $c->container_not_found unless $store->index->exists($key);

    my $files = $store->index->files($key);

    my $file = $files->get($filename);

    return Dancer::send_file(
        'public/images/thumbnail_dummy.png',
        system_path => 1,
        filename    => 'thumbnail_dummy.png'
    ) unless $file;

    # send_file(
    #     \"dummy",    # anything, as long as it's a scalar-ref
    #     streaming => 1,    # enable streaming
    #     callbacks => {
    #         override => sub {
    #             my ($respond, $response) = @_;
    #             my $content_type = $file->{content_type};
    #
    #             my $http_status_code = 200;
    #
    #           # Tech.note: This is a hash of HTTP header/values, but the
    #           #            function below requires an even-numbered array-ref.
    #             my @http_headers = (
    #                 'Content-Type' => $content_type,
    #                 'Cache-Control' =>
    #                     'no-store, no-cache, must-revalidate, max-age=0',
    #                 'Pragma' => 'no-cache'
    #             );
    #
    #      # Send the HTTP headers
    #      # (back to either the user or the upstream HTTP web-server front-end)
    #             my $writer = $respond->([$http_status_code, \@http_headers]);
    #
    #             $files->stream($c->io_from_plack_writer($writer), $file);
    #         },
    #     },
    # );
}

sub add_thumbnail {
    my $c     = $_[0];
    my $key      = $c->param('key');
    my $filename = $c->param('filename'); #TODO: Check this

    my $thumbnailer_package
        = librecat->config->{filestore}->{access_thumbnailer}->{package};
    my $thumbnailer_options
        = librecat->config->{filestore}->{access_thumbnailer}->{options};

    my $pkg = Catmandu::Util::require_package($thumbnailer_package,
        'LibreCat::Worker');
    my $worker = $pkg->new(%$thumbnailer_options);

    my $response = $worker->work({key => $key, filename => $filename,});

    $response;
}

sub remove_thumbnail {
    my $c     = $_[0];
    my $key    = $c->param('key');

    my $thumbnailer_package
        = librecat->config->{filestore}->{access_thumbnailer}->{package};
    my $thumbnailer_options
        = librecat->config->{filestore}->{access_thumbnailer}->{options};

    my $pkg = Catmandu::Util::require_package($thumbnailer_package,
        'LibreCat::Worker');
    my $worker = $pkg->new(%$thumbnailer_options);

    my $response = $worker->work({key => $key, delete => 1});

    $response;
}

sub container_not_found {
    my $c     = $_[0];
    my $key    = $c->param('key');
    my $error = {
        status => '404',
        title  => "container $key not found",
        source => {parameter => 'key'},
    };
    $c->render(json => {errors => [$error]}, status => 404);
}

sub file_not_found {
    my $c     = $_[0];
    my $key    = $c->param('key');
    my $file = $c->param('file');
    my $error = {
        status => '404',
        title  => "file '$file' not found in container '$key'",
        source => {parameter => 'key'},
    };
    $c->render(json => {errors => [$error]}, status => 404);
}

sub get_file_store {
    # my $c = $_[0];

    my $file_store = librecat->config->{filestore}->{default}->{package};
    my $file_opts = librecat->config->{filestore}->{default}->{options} // {};

    return undef unless $file_store;

    my $pkg = Catmandu::Util::require_package($file_store,
        'Catmandu::Store::File');
    $pkg->new(%$file_opts);
}

sub get_access_store {
    # my $c = $_[0];

    my $access_store = librecat->config->{filestore}->{access}->{package};
    my $access_opts = librecat->config->{filestore}->{access}->{options} // {};

    return undef unless $access_store;

    my $pkg = Catmandu::Util::require_package($access_store,
        'Catmandu::Store::File');
    $pkg->new(%$access_opts);
}

1;
