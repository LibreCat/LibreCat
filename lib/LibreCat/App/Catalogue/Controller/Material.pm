package LibreCat::App::Catalogue::Controller::Material;

use Catmandu::Sane;
use Catmandu;
use LibreCat::App::Helper;
use Exporter qw/import/;

our @EXPORT = qw/update_related_material/;

my $relations_link   = h->config->{lists}->{relations_link};
my $relations_record = h->config->{lists}->{relations_record};
my $rd_relation      = h->config->{lists}->{relations_rd};

sub update_related_material {
    my $pub                   = shift;
    my $related_material_link = $pub->{related_material}->{'link'}
        if $pub->{related_material}->{'link'};
    my $related_material_record;
    @$related_material_record = grep %$_,
        @{$pub->{related_material}->{record}}
        if $pub->{related_material}->{record};

    # get old related material (to be able to remove deleted relations)
    my $hit = Catmandu->store('main')->bag('publication')->get($pub->{_id});
    my $old_related_material_record = $hit->{related_material}->{record}
        if $hit->{related_material} and $hit->{related_material}->{record};

    foreach my $rm (@$related_material_record) {

        # set relation in other record
        if ($rm->{id}) {
            my $opposite
                = Catmandu->store('main')->bag('publication')->get($rm->{id});

            push(@$relations_record, @$rd_relation);

            my ($ref)
                = grep {$_->{relation} eq $rm->{relation}} @$relations_record;
            my $op_relation = $ref->{opposite};

            if (   !$opposite->{related_material}
                or !$opposite->{related_material}->{record})
            {
                push @{$opposite->{related_material}->{record}},
                    {
                    id       => $pub->{_id},
                    status   => $pub->{status},
                    relation => $op_relation
                    };
            }
            elsif ( $opposite->{related_material}
                and $opposite->{related_material}->{record})
            {
                my ($ref) = grep {
                            $_->{relation} eq $op_relation
                        and $_->{id} eq $pub->{_id}
                } @{$opposite->{related_material}->{record}};
                if (!$ref) {
                    push @{$opposite->{related_material}->{record}},
                        {
                        id       => $pub->{_id},
                        status   => $pub->{status},
                        relation => $op_relation
                        };
                }
                else {
                    $ref->{status} = $pub->{status};
                }
            }
            my $saved
                = Catmandu->store('main')->bag('publication')->add($opposite);
            h->publication->add($saved);
            h->publication->commit;

            $rm->{status} = $opposite->{status};
        }
    }
    if ($old_related_material_record) {

        #@A @$old_related_material_record = 1..9;
        #@B @$related_material_record = (2, 4, 6, 8);
        #my @dense = grep %$_, @$related_material_record;
        my %B = map {$_->{id} => 1} @$related_material_record;
        my @recs = grep {not $B{$_->{id}}} @$old_related_material_record;

        #$recs = [$recs] if ref $recs ne "ARRAY";
        my $q;
        my $query = "";
        if (@recs) {
            foreach my $id (@recs) {
                $query .= " OR id=" . $id->{id};
            }
            $query =~ s/^ OR //g;
            $query = "(" . $query . ")";

            push @{$q->{cql_quey}}, $query;

            $q->{limit} = 1000;

            my $hits = LibreCat->searcher->search('publication', $q);
            my $return_hit;

            if ($hits->{total}) {
                $hits->each(
                    sub {
                        my $rec = $_[0];
                        $return_hit = $rec;

                        if (    $rec->{related_material}
                            and $rec->{related_material}->{record})
                        {
                            foreach my $rel (
                                @{$rec->{related_material}->{record}})
                            {
                                if ($rel->{id} eq $pub->{_id}) {
                                    $rel = {};
                                }
                            }
                            @{$rec->{related_material}->{record}} = grep %$_,
                                @{$rec->{related_material}->{record}};
                            if (!$rec->{related_material}->{record}->[0]) {
                                delete $rec->{related_material}->{record};
                                if (!%{$rec->{related_material}}) {
                                    delete $rec->{related_material};
                                }
                            }
                            my $saved
                                = Catmandu->store('main')->bag('publication')
                                ->add($rec);
                            h->publication->add($saved);
                            h->publication->commit;
                        }
                    }
                );

                #return $return_hit;
            }
        }

    }
}

1;
