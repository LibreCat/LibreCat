package Catmandu::Bag::IdGenerator::UniBiDefault;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Bag::IdGenerator';

sub generate {
    my ($self, $bag) = @_;

    my $id;

    $bag->store->transaction(
        sub {
            my $info_bag = $bag->store->bag($bag->name.'_info');

            # TODO this is temporary, there's no more need for the default store after this
            # migration
            #my $rec = $info_bag->get_or_add('id', {latest => '0'});
            my $rec = $info_bag->get('id');
            unless ($rec) {
                my $old_store = Catmandu->store;
                $old_store->transaction(sub {
                    if ($rec = $old_store->bag->get('1')) {
                        $old_store->bag->delete_all;
                    }
                });
                $rec ||= {latest => '0'};
                $rec->{_id} = 'id';
            }

            $id = ++$rec->{latest};
            $info_bag->add($rec);
        }
    );

    "$id";
}

1;
