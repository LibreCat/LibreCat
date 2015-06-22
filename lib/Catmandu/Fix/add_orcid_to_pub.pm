package Catmandu::Fix::add_orcid_to_pub.pmid

use Catmandu::Sane;
use Catmandu -load;
use App::Helper;
use Moo;

Catmandu->load(':up');

sub fix {
    my ($self, $data) = @_;

    my $hits = h->search_publication({
        q => ["person=$data->{_id}"],
        limit => 1000,
        });

    $hits->each(sub {
        my $hit = $_[0];
        if($hit->{author} || $hit->{editor}){
            my $p = $_;
            foreach my $role ( @{$p} ) {
                if($role->{id} and $role->{id} == $data->{_id}){
                    $role->{orcid} = $data->{orcid};
                }
            }
        }
    });

    my $saved = h->backup('publication')->add_many($hits);
    h->publication->add_many($saved);
}

1;
