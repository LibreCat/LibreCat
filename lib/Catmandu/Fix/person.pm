package Catmandu::Fix::person;

=pod

=head1 NAME

Catmandu::Fix::person - generate a full_name and orcid if not exists

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use LibreCat::App::Helper;
use Moo;

has 'helper' => (is => 'lazy');

sub _build_helper {
    LibreCat::App::Helper::Helpers->new;
}

sub fix {
    my ($self, $data) = @_;
    my @types
        = qw(author editor translator supervisor corporate_editor applicant);

    my $users = $self->helper->main_user;

    foreach my $author_type (@types) {
        next unless $data->{$author_type};
        foreach my $au (@{$data->{$author_type}}) {

            # Update the full_name
            if (is_string($au->{full_name})) {

                # ok
            }
            elsif (is_string($au->{first_name})
                && is_string($au->{last_name}))
            {
                $au->{full_name}
                    = $au->{last_name} . ", " . $au->{first_name};
            }

            # Update the orcid
            if ($au->{orcid}) {

                # ok
            }
            elsif (is_string($au->{id})) {
                my $user = $users->get($au->{id});
                $au->{orcid} = $user->{orcid} if ($user && $user->{orcid});
            }
        }
    }

    return $data;
}

1;
