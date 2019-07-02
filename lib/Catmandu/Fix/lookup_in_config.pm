package Catmandu::Fix::lookup_in_config;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Catmandu::Util::Path qw(as_path);
use LibreCat -self;
use Moo;
use namespace::clean;
use Catmandu::Fix::Has;

with 'Catmandu::Fix::Builder';

has path        => (fix_arg => 1);
has config_path => (fix_arg => 1);
has default     => (fix_opt => 1, predicate => 1);
has delete      => (fix_opt => 1);
has config_hash => (is => 'lazy');

sub _build_config_hash {
    my $config = as_path($_[0]->config_path)->getter->(librecat->config)->[0];
    ref $config eq 'HASH' ? $config : +{};
}

sub _build_fixer {
    my ($self)      = @_;
    my $path        = as_path($self->path);
    my $config_path = $self->config_path;
    my $has_default = $self->has_default;
    my $default     = $self->default;
    my $delete      = $self->delete;
    my $config_hash = $self->config_hash;

    $path->updater(
        sub {
            my $val = $_[0];

            if (   is_value($val)
                && defined($config_hash)
                && defined(my $new_val = $config_hash->{$val}))
            {
                return $new_val;
            }
            elsif ($delete) {
                return undef, 1, 1;
            }
            elsif ($has_default) {
                return $default;
            }
            return undef, 1, 0;
        }
    );
}

1;

__END__

=pod

=head1 NAME

Catmandu::Fix::lookup_in_config - does a lookup in the LibreCat configuration

=cut
