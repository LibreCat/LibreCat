package LibreCat::Controller::FileApi;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat -self;
use Mojo::Base "Mojolicious::Controller";
use IO::Handle::Util;
use IO::File;
use URI::Escape qw(uri_escape_utf8);

=head2 GET /api/v1/file

    Response:
        Content-Type: text/plain

    Body: list of identifiers, separated by newline

    Question: can we really implement such a long response in JSON API?

=cut

sub show_filestore {

    my $c = $_[0];

    my $h = $c->res->headers;
    $h->header("Content-Type" => "text/plain");
    $h->header(
        "Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0");
    $h->header("Pragma" => "no-cache");

    $c->get_file_store()->index->each(
        sub {

            $c->write($_[0]->{_id} . "\n");

        }
    );

    $c->finish();

}

=head2 GET /api/v1/file/:container_id
    {
        "data" : {
            "type": "container",
            "id": "mycontainer",
            "links" : {
                "self": "http://localhost:5000/api/v1/file/mycontainer"
            },
            "attributes": {
                "file": [
                    {
                        "id" : "myfile.jpg",
                        "type" : "file",
                        "attributes" : {
                            "size": 100,
                            "md5" : "md5",
                            "modified": 1234000,
                            "created" : 1234000
                        },
                        "links": {
                            "self": "http://localhost:5000/api/v1/file/mycontainer/myfile.jpg"
                        }
                    }
                ]
            }
        }
    }

=cut

sub show_container {

    my $c = $_[0];

    my $container_id = $c->param("container_id");

    my $store = $c->get_file_store();
    my $files = $store->index->files($container_id);

    return $c->container_not_found() unless defined($files);

    my $container_url = $c->url_for()->to_abs();

    my $doc = {
        data => {
            type       => "container",
            id         => $container_id,
            links      => {self => $container_url},
            attributes => {file => []}
        }
    };

    $files->each(
        sub {
            my $file = $_[0];
            push @{$doc->{data}->{attributes}->{file}},
                +{
                id         => $file->{_id},
                type       => "file",
                attributes => {
                    size     => $file->{size},
                    md5      => $file->{md5},
                    modified => $file->{modified},
                    created  => $file->{created}
                },
                links => {
                    self => $container_url . "/"
                        . uri_escape_utf8($file->{_id})
                }
                };
        }
    );

    $c->render(json => $doc);

}

=head2 POST /api/v1/file

    request body:

        { "data" : { "id" : "myid", type => "container" } }

    If data.id is not set, it will be generated

    response body:

        {
            "data": {
                "type"  : "container",
                "id"    : "myid",
                "links" : {
                    "self" : "http://localhost:5000/api/v1/file/myid"
                }
            }
        }

=cut

sub create_container {

    my $c = $_[0];

    my $json_api = $c->req->json();

    my ($valid, $error) = $c->validate_create_container($json_api);

    return $c->do_error($error->{status}, $error) unless $valid;

    my $container_id = $json_api->{data}->{id}
        // publications()->generate_id();
    my $store = $c->get_file_store();

    return $c->do_error(400,
        +{status => "400", title => "container already exists"})
        if $store->index->exists($container_id);

    $store->index->add({_id => $container_id});

    $c->render(
        json => {
            data => {
                type  => "container",
                id    => $container_id,
                links => {
                    self => $c->url_for("/api/v1/file")->to_abs() . "/"
                        . uri_escape_utf8($container_id)
                }
            }
        },
        status => 201
    );

}

=head2 GET /api/v1/file/:container_id/:file_name

    Response: file binary data

    Question: part of JSON API?

=cut

sub show_file {

    my $c = $_[0];

    my $container_id = $c->param("container_id");
    my $file_name    = $c->param("file_name");

    my $store = $c->get_file_store();
    my $files = $store->index->files($container_id);

    return $c->container_not_found() unless defined $files;

    my $file = $files->get($file_name);

    return $c->file_not_found unless $file;

    my $h = $c->res->headers;
    $h->header("Content-Type"   => $file->{content_type});
    $h->header("Content-Length" => $file->{size});

    $files->stream($c->get_io_writer(), $file);

}

=head2 DELETE /api/v1/file/:container_id

    Response:
        code: 204
        body: empty

=cut

sub remove_container {

    my $c = $_[0];

    my $container_id = $c->param("container_id");
    my $store        = $c->get_file_store();

    return $c->container_not_found()
        unless $store->index->exists($container_id);

    $store->index->delete($container_id);

    $c->res->code(204);
    $c->finish();

}

=head2 DELETE /api/v1/file/:container_id/:file_name

    Response:
        code: 204
        body: empty

=cut

sub remove_file {

    my $c            = $_[0];
    my $container_id = $c->param("container_id");
    my $file_name    = $c->param("file_name");

    my $store = $c->get_file_store();

    my $files = $store->index->files($container_id);

    return $c->container_not_found() unless defined $files;

    my $file = $files->get($file_name);

    return $c->file_not_found() unless defined $file;

    $files->delete($file_name);

    $c->res->code(204);
    $c->finish();

}

=head2 POST /api/v1/file/:container_id

    Request:

        Content-Type: multipart/form-data
        upload parameter must be 'file'

    Response code: 201
    Response body:

        {
            "data" : {
                "id" : "myfile.jpg",
                "type" : "file",
                "attributes" : {
                    "size"     : 100,
                    "md5"      : "md5",
                    "modified" : 1234500,
                    "created"  : 1234500
                },
                "links" : {
                    "self" : "http://localhost/api/v1/file/mycontainer/myfile.jpg"
                },
                "relationships" : {
                    "container" : {
                        "data" : {
                            "type" : "container",
                            "id"   : "mycontainer",
                            "links" : {
                                "self" : "http://localhost/api/v1/file/mycontainer"
                            }
                        }
                    }
                }
            }
        }

=cut

sub upload_file {

    my $c = $_[0];

    my $container_id = $c->param("container_id");

    my $store = $c->get_file_store;

    return $c->container_not_found()
        unless $store->index->exists($container_id);

    my $files = $store->index->files($container_id);

    my $upload = $c->req->upload("file");

    unless ($upload) {

        return $c->do_error(
            400,
            {
                status => "400",
                id     => "no_upload_file",
                title  => "no upload file with name 'file' given",
                source => {parameter => "file"}
            }
        );

    }

    $files->upload(IO::File->new($upload->asset->to_file->path), $upload->filename);

    my $file = $files->get($upload->filename);

    my $container_url = $c->url_for("/api/v1/file")->to_abs() . "/"
        . uri_escape_utf8($container_id);

    $c->render(
        json => {
            data => {
                id         => $file->{_id},
                type       => "file",
                attributes => {
                    size     => $file->{size},
                    md5      => $file->{md5},
                    modified => $file->{modified},
                    created  => $file->{created}
                },
                links => {
                    self => $container_url . "/"
                        . uri_escape_utf8($file->{_id})
                },
                relationships => {
                    container => {
                        data => {
                            type  => "container",
                            id    => $container_id,
                            links => {self => $container_url}
                        }
                    }
                }
            }
        },
        status => 201
    );

}

sub do_error {

    my ($c, $status, $error) = @_;
    $c->render(json => {errors => [$error]}, status => $status);

}

sub container_not_found {

    my $c            = $_[0];
    my $container_id = $c->param("container_id");
    $c->do_error(
        404,
        {
            status => "404",
            id     => "container_not_found",
            title  => "container $container_id not found",
            source => {parameter => "container_id"},
        }
    );

}

sub file_not_found {

    my $c            = $_[0];
    my $container_id = $c->param("container_id");
    my $file_name    = $c->param("file_name");
    $c->do_error(
        404,
        {
            status => "404",
            id     => "file_not_found",
            title =>
                "file '$file_name' not found in container '$container_id'",
            source => {parameter => "file_name"}
        }
    );

}

sub get_file_store {
    my $c = $_[0];

    state $fs = do {

        my $config     = librecat->config->{filestore}->{"default"};
        my $file_store = $config->{package};
        my $file_opts  = $config->{options} // {};

        my $pkg = Catmandu::Util::require_package($file_store,
            "Catmandu::Store::File");
        $pkg->new(%$file_opts);

    };
}

sub get_access_store {
    my $c = $_[0];

    state $as = do {

        my $config       = librecat->config->{filestore}->{access};
        my $access_store = $config->{package};
        my $access_opts  = $config->{options} // {};

        my $pkg = Catmandu::Util::require_package($access_store,
            "Catmandu::Store::File");
        $pkg->new(%$access_opts);

    };

}

sub get_io_writer {
    my $c = $_[0];

    IO::Handle::Util::io_prototype(
        write => sub {
            my $self = shift;
            $c->write(@_);
        },
        syswrite => sub {
            my $self = shift;
            $c->write(@_);
        },
        close => sub {
            $c->finish;
        }
    );
}

sub publications {
    state $p = librecat->model("publication");
}

sub validate_create_container {

    my ($c, $json_api) = @_;

    return 0,
        +{status => "400", title => "top level document should be object"}
        unless is_hash_ref($json_api);

    return 0, +{status => "400", title => "data should be object"}
        unless is_hash_ref($json_api->{data});

    return 0, +{status => "400", title => "data.type should be 'container'"}
        unless is_string($json_api->{data}->{type})
        && $json_api->{data}->{type} eq "container";

    return 0, +{status => "400", title => "data.id should be string"}
        if defined($json_api->{data}->{id})
        && !is_string($json_api->{data}->{id});

    1;

}

1;
