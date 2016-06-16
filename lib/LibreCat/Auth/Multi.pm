package LibreCat::Auth::Multi;

use Catmandu::Sane;
use Catmandu::Util qw(is_instance require_package);
use Moo;
use namespace::clean;

with 'LibreCat::Auth';

has methods => (is => 'ro', required => 1,);

has _auths => (is => 'lazy', builder => '_build_auths',);

sub _build_auths {
    my ($self) = @_;
    [
        map {
            is_instance($_)
                ? $_
                : require_package($_->{package})->new($_->{options});
        } @{$self->methods}
    ];
}

sub _authenticate {
    my ($self, $params) = @_;
    for my $auth (@{$self->_auths}) {
        $auth->authenticate($params) && return 1;
    }
    0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Auth::Multi - A LibreCat authentication package that
tries multiple authentication methods.

=head1 SYNOPSIS

    use LibreCat::Auth::Multi;

    my $auth = Auth::Multi->new(
        methods => [
            {
                package => 'LibreCat::Auth::Simple',
                options => {
                    users => { demo => {password => 'demo'} },
                },
            },
            {
                package => 'LibreCat::Auth::LDAP',
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

L<LibreCat::Auth>

=cut
