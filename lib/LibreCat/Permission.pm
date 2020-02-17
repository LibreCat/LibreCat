package LibreCat::Permission;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use LibreCat -self;
use Moo;
use namespace::clean;

with 'Catmandu::Logger';

has model => (is => 'lazy');
has _permision_instances => (is => 'ro', init_arg => undef, default => sub {+{}});

sub BUILD {
    my ($self) = @_;

    my $model = $self->model;

    unless (librecat->has_model($model)) {
        die "Model $model not supported.";
    }

    if ($model eq 'publication') {
        return require_package('LibreCat::Permission::Publication')->new();
    }
    else {
        return require_package('LibreCat::Permission::Generic')->new();
    }
}

# sub AUTOCAN {
#     my ($self, $method)
# }


1;

__END__

=pod

=head1 NAME

LibreCat::Permission - LibreCat permission role

=cut
