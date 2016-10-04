package Catmandu::Fix::add_orcid_to_pub;

use Catmandu::Sane;
use Catmandu;
use LibreCat::App::Helper;
use Moo;

sub fix {
    my ($self, $data) = @_;

    my $q;
    push @$q, "person=$data->{_id}";

    my $hits = h->search_publication({q => $q, limit => 1000,});

    if ($hits and $hits->{total}) {
        $hits->each(
            sub {
                my $hit = $_[0];
                if ($hit->{author}) {
                    foreach my $person (@{$hit->{author}}) {
                        if ($person->{id} and $person->{id} eq $data->{_id}) {
                            $person->{orcid} = $data->{orcid};
                        }
                    }
                }
                if ($hit->{editor}) {
                    foreach my $person (@{$hit->{editor}}) {
                        if ($person->{id} and $person->{id} eq $data->{_id}) {
                            $person->{orcid} = $data->{orcid};
                        }
                    }
                }
                if ($hit->{supervisor}) {
                    foreach my $person (@{$hit->{supervisor}}) {
                        if ($person->{id} and $person->{id} eq $data->{_id}) {
                            $person->{orcid} = $data->{orcid};
                        }
                    }
                }
                if ($hit->{translator}) {
                    foreach my $person (@{$hit->{translator}}) {
                        if ($person->{id} and $person->{id} eq $data->{_id}) {
                            $person->{orcid} = $data->{orcid};
                        }
                    }
                }
                my $saved = h->backup_publication_static->add($hit);
                h->publication->add($saved);
                h->publication->commit;
            }
        );
    }

    return $data;

}

1;
