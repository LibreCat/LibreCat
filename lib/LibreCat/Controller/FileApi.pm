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

    my $index = $c->_get_file_store->index
        // return $c->not_found("No filestore defined or empty.");

    my $data;
    $index->each(sub {
        push @$data, $_[0];
    });

    $c->render(json => {data => $data});
}

sub show_container {
    my $c     = $_[0];
    my $key   = $c->param('key');
    my $store = $c->_get_file_store;

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
        $c->not_found("container $key not found");
    }
}

sub show_file {
    my $c        = $_[0];
    my $key      = $c->param('key');
    my $filename = $c->param('filename');

    my $store = $c->_get_file_store;

    $c->not_found("container $key not found") unless $store->index->exists($key);

    my $files = $store->index->files($key);
    my $file  = $files->get($filename);

    $c->not_found("file $filename not found in container $key") unless $file;

    # Start writing directly with a drain callback
    # https://mojolicious.org/perldoc/Mojolicious/Guides/Rendering#Streaming
    $c->res->headers->content_length(length $body);

    my $drain;

    $drain = sub {
        my $c = shift;
        my $chunk = substr $body, 0, 1, '';
        $drain = undef unless length $body;
        $c->write($chunk, $drain);
    };

    $c->$drain;

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
    $c->render(json => {data => $filename});
}

sub remove_container {
    my $c   = $_[0];
    my $key = $c->param('key');

    my $store = $c->_get_file_store;

    if ($store->index->exits($key)) {
        $store->index->delete($key);
        $c->render(json => {ok => 1});
    }
    else {
        $c->not_found("container $key not found");
    }
}

sub remove_file {
    my $c        = $_[0];
    my $key      = $c->param('key');
    my $filename = $c->param('filename');

    my $store = $c->_get_file_store;

    if ($store->index->exists($key)) {
        my $files = $store->index->files($key);

        my $file = $files->get($filename);

        if (defined $file) {
            $files->delete($filename);
            $c->render(json => {ok => 1});
        }
        else {
            $c->not_found("container $key not found");
        }
    }
    else {
        $c->not_found("file $filename not found in container $key");
    }
}

sub upload_file {
    my $c   = $_[0];
    my $key = $c->param('key');

    my $store = $c->_get_file_store;

    unless ($store->index->exists($key)) {
        $store->index->add($key);
    }

    my $files = $store->index->files($key);

    my $file = request->upload('file');

    unless ($file) {
        $c->render(json => {errors => ["need a file"]}, status => 400)
    }

    $files->add(IO::File->new($file->{tempname}), $file->{filename});

    $c->render(json => {ok => 1})
}

sub not_found {
    my ($c, $msg) = @_;
    my $key = $c->param('key');
    my $error
        = {status => '404', title => $msg, source => {parameter => 'key'},};
    $c->render(json => {errors => [$error]}, status => 404);
}

sub _get_file_store {
    my $file_store = librecat->config->{filestore}->{default}->{package};
    my $file_opts = librecat->config->{filestore}->{default}->{options} // {};

    return undef unless $file_store;

    my $pkg = Catmandu::Util::require_package($file_store,
        'Catmandu::Store::File');
    $pkg->new(%$file_opts);
}

1;
