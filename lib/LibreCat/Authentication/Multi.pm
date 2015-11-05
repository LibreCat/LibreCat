package LibreCat::Authentication::Multi;

use Catmandu::Sane;
use Catmandu::Util qw(is_instance require_package);
use Moo;

with 'LibreCat::Authentication';

has methods => (
    is => 'ro',
    required => 1,
);

has _instances => (
    is => 'lazy',
    builder => '_build_instances',
);

sub _build_instances {
    my ($self) = @_;
    [map {
        is_instance($_)
            ? $_
            : require_package($_->{package})->new($_->{options});
    } @{$self->methods}];
}

sub _authenticate {
    my ($self, $params) = @_;
    for (@{$self->_instances}) {
        $_->authenticate($params) && return 1;
    }
    0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Authentication::Multi - A LibreCat authentication package that
tries multiple authentication methods.

=head1 SYNOPSIS

    use LibreCat::Authentication::Multi;

    my $auth = Authentication::Multi->new(
        methods => [
            {
                package => 'LibreCat::Authentication::Simple',
                options => {
                    users => { demo => {password => 'demo'} },
                },
            },
            {
                package => 'LibreCat::Authentication::LDAP',
                options => {
                    # ...
                },
            },
        ]
    );

    if ($auth->authenticate({username => $username,
            password => $password})) {
        say "logged in";
    }
    else {
        say "error";
    }

=head1 CONFIG

=head2 methods

See synopsis.

=head1 SEE ALSO

L<LibreCat::Authentication>

=cut
