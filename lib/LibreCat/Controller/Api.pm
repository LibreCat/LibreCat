package LibreCat::Controller::Api;

use Catmandu::Sane;
use LibreCat -self;
use Data::Dumper;
use JSON::MaybeXS;
use Mojo::Base 'Mojolicious::Controller';

sub default {
    my $c = shift;
    $c->render(json => {foo => 'bar'});
}

sub show {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $recs  = librecat->$model;
    my $rec   = $recs->get($id) || return $c->not_found;
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
    my $data  = decode_json($c->req->body);
    my $recs  = librecat->$model;

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
            $c->render(json => {data => $d});
        }
    );
}

sub add {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $data  = decode_json($c->req->body);
    my $recs  = librecat->$model;

    # does record exist?
    unless ($recs->get($data->{_id})) {
        $c->not_found;
    }

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

sub update_fields {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $data  = decode_json($c->req->body);
    my $recs  = librecat->$model;

    # does record exist?
    unless ($recs->get($data->{_id})) {
        $c->not_found;
    }

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

sub remove {
    my $c     = $_[0];
    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $recs  = librecat->$model;
    my $rec   = $recs->delete($id) || return $c->not_found;

    my $data = {
        type       => $model,
        id         => $id,
        attributes => {status => 'deleted'},
        links      => {self => $c->url_for->to_abs,},
    };
    $c->render(json => {data => $data});
}

sub get_versions {
    my $c = $_[0];

    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $recs  = librecat->$model;
    my $versions = $recs->get_versions($id) || return $c->not_found;
    my $data = {
        type       => $model,
        id         => $id,
        attributes => $versions,
        links      => {self => $c->url_for->to_abs,},
    };
    $c->render(json => {data => $data});
}

sub get_version {
    my $c = $_[0];

    my $model = $c->param('model');
    my $id    = $c->param('id');
    my $recs  = librecat->$model;
    my $version = $recs->get_version($id) || return $c->not_found;
    my $data = {
        type       => $model,
        id         => $id,
        attributes => $version,
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
    my $model = $c->param('model');

    my $error = {status => '400', validation_error => $validation_errors,};

    $c->render(json => {errors => [$error]}, status => '400');
}

1;

__END__

=pod

=head1 NAME

LibreCat::Controller::Api -

=head2 SEE ALSO

L<LibreCat>, L<Mojolicious::Plugin::LibreCat::Api>

=cut
