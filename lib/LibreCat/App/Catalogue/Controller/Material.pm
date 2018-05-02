package LibreCat::App::Catalogue::Controller::Material;

use Catmandu::Sane;
use Catmandu;
use LibreCat::App::Helper;
use Exporter qw/import/;

our @EXPORT = qw/update_related_material/;

sub update_related_material {
    my $pub = shift;

    return unless $pub->{related_material};

    #--- Create a inverse relation name database ---
    my $relations_record = h->config->{lists}->{relations_record} // [];
    my $rd_relation      = h->config->{lists}->{relations_rd} // [];

    my $lookup_relation = {};

    for (@$relations_record,@$rd_relation) {
        my $relation = $_->{relation};
        my $opposite = $_->{opposite};
        $lookup_relation->{$relation} = $opposite;
    }
    #---

    # First delete the relations to this record from previous record (in order to
    # remove deleted relations from targetted records)
    my $hit = h->main_publication->get($pub->{_id});

    my $previous_related_material_record = $hit->{related_material}->{record} // [];

    foreach my $rm (@$previous_related_material_record) {
        next unless $rm->{id};

        my $target = h->main_publication->get($rm->{id});

        next unless $target;

        my $target_related_material_record = $target->{related_material}->{record} // [];

        my @new_relations;

        for (@$target_related_material_record) {
            if ($_->{id} eq $pub->{_id}) {
                # remove
            }
            else {
                # keep
                push @new_relations , $_;
            }
        }

        $target->{related_material}->{record} = \@new_relations;

        my $saved = h->main_publication->add($target);
        h->main_publication->commit;
        h->publication->add($saved);
        h->publication->commit;
    }

    # (Re)create the relations to other records as reverse links
    my $current_related_material_record = $pub->{related_material}->{record} // [];

    foreach my $rm (@$current_related_material_record) {
        next unless $rm->{id};

        my $target = h->main_publication->get($rm->{id});

        next unless $target;

        # Find the name of the reverse link
        my $inverse_relation = $lookup_relation->{ $rm->{relation} };

        unless ($inverse_relation) {
            h->log->error("found not inverse relation for `" . $rm->{relation} . "`");
            $inverse_relation = 'other';
        }
        
        my $target_related_material_record = $target->{related_material}->{record} // [];

        my @new_relations;

        my $found = 0;

        for (@$target_related_material_record) {
            if ($_->{id} eq $pub->{_id}) {
                $found = 1;
                $_->{status}   = $pub->{status};
                $_->{relation} = $inverse_relation;
            }
            push @new_relations , $_;
        }

        if (!$found) {
            push @new_relations, {
                    id       => $pub->{_id},
                    status   => $pub->{status},
                    relation => $inverse_relation
            };
        }

        $target->{related_material}->{record} = \@new_relations;

        my $saved = h->main_publication->add($target);
        h->main_publication->commit;
        h->publication->add($saved);
        h->publication->commit;

        $rm->{status} = $target->{status};
    }
}

1;
