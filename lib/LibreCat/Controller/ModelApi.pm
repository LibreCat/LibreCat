package LibreCat::Controller::ModelApi;

use Catmandu::Sane;
use Hash::Merge::Simple qw(merge);
use LibreCat -self;
use Mojo::Base 'Mojolicious::Controller';
use namespace::clean;

sub show {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $recs  = librecat->model($model) // return $c->not_found;
    my $rec   = $recs->get($id) // return $c->not_found;
    delete $rec->{_id};
    my $data = {
        type       => $model,
        id         => $id,
        attributes => $rec,
        links      => {self => $c->url_for->to_abs,},
    };
    $c->render(json => {data => $data});
}

sub create {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $recs  = librecat->model($model) // return $c->not_found;
    my $data  = $c->maybe_decode_json($c->req->body) // return $c->json_not_valid;

    librecat->hook("api-$model-update")->fix_around(
        $data,
        sub {
            $recs->add(
                $data,
                on_validation_error => sub {
                    my ($x, $errors) = @_;
                    return $c->not_valid($errors);
                },
                on_success => sub {
                    my $d = {
                        type       => $model,
                        id         => $data->{_id},
                        attributes => $data,
                        links      => {self => $c->url_for->to_abs,},
                    };

                    # send created status 201
                    $c->render(json => {data => $d}, status => 201);
                }
            );
        }
    );

}

sub update {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $recs  = librecat->model($model) // return $c->not_found;
    my $data  = $c->maybe_decode_json($c->req->body) // return $c->json_not_valid;

    # does record exist?
    unless ($recs->get($id)) {
        $c->not_found;
    }

    librecat->hook("api-$model-update")->fix_around(
        $data,
        sub {
            $recs->add(
                $data,
                on_validation_error => sub {
                    my ($x, $errors) = @_;
                    return $c->not_valid($errors);
                },
                on_success => sub {
                    my $d = {
                        type       => $model,
                        id         => $data->{_id},
                        attributes => $data,
                        links      => {self => $c->url_for->to_abs,},
                    };

                    $c->render(json => {data => $d});
                }
            );
        }
    );
}

sub update_fields {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $recs  = librecat->model($model) // return $c->not_found;
    my $data  = $c->maybe_decode_json($c->req->body) // return $c->json_not_valid;

    # does record exist?
    my $rec;
    unless ($rec = $recs->get($id)) {
        $c->not_found;
    }

    $data = merge($rec, $data);

    librecat->hook("api-$model-update")->fix_around(
        $data,
        sub {
            $recs->add(
                $data,
                on_validation_error => sub {
                    my ($x, $errors) = @_;
                    return $c->not_valid($errors);
                },
                on_success => sub {
                    my $d = {
                        type       => $model,
                        id         => $data->{_id},
                        attributes => $data,
                        links      => {self => $c->url_for->to_abs,},
                    };

                    $c->render(json => {data => $d});
                }
            );
        }
    );
}

sub remove {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $recs  = librecat->model($model) // return $c->not_found;
    my $rec   = $recs->get($id) // return $c->not_found;

    librecat->hook("api-$model-delete")->fix_around(
        $rec,
        sub {
            $recs->delete($id);
        }
    );

    my $data = {
        type       => $model,
        id         => $id,
        attributes => {status => 'deleted'},
        links      => {self => $c->url_for->to_abs,},
    };
    $c->render(json => {data => $data});
}

sub show_history {
    my $c = $_[0];

    my $model    = $c->param('model');
    my $id       = $c->param('id');
    my $recs     = librecat->model($model) // return $c->not_found;
    my $versions = $recs->get_history($id) // return $c->not_found;
    my $data     = {
        type       => $model,
        id         => $id,
        attributes => $versions,
        links      => {self => $c->url_for->to_abs,},
    };
    $c->render(json => {data => $data});
}

sub show_version {
    my $c = $_[0];

    my $model   = $c->param('model');
    my $id      = $c->param('id');
    my $version = $c->param('version');
    my $recs    = librecat->model($model) // return $c->not_found;
    my $rec     = $recs->get_version($id, $version) // return $c->not_found;
    my $data    = {
        type       => $model,
        id         => $id,
        attributes => $rec,
        links      => {self => $c->url_for->to_abs,},
    };
    $c->render(json => {data => $data});
}

sub not_found {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $error = {
        status => '404',
        title  => "$model $id not found",
        source => {parameter => 'id'},
    };
    $c->render(json => {errors => [$error]}, status => 404);
}

sub not_valid {
    my ($c, $validation_errors) = @_;

    my $error = {status => '400', validation_error => $validation_errors,};

    $c->render(json => {errors => [$error]}, status => 400);
}

sub json_not_valid {
    my ($c) = @_;

    my $error = {status => '400', title => ['malformed JSON string'],};

    $c->render(json => {errors => [$error]}, status => 400);
}

1;

__END__

=pod

=head1 NAME

LibreCat::Controller::ModelApi - a model api controller used by L<Mojolicious::Plugin::LibreCat::Api>

=head1 SYNOPSIS

=head2 SEE ALSO

L<LibreCat>, L<Mojolicious::Plugin::LibreCat::Api>

=cut
