package Catmandu::Bag::IdGenerator::Incremental;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Bag::IdGenerator';

sub generate {
    my ($self, $bag) = @_;

    my $id;

    $bag->store->transaction(
        sub {
            my $info_bag = $bag->store->bag('info');
            my $info_key = $bag->name . '_id';
            my $rec      = $info_bag->get_or_add($info_key, {latest => '0'});
            $id = ++$rec->{latest};
            $rec->{latest} = "$rec->{latest}";
            $info_bag->add($rec);
            $info_bag->commit;
        }
    );

    "$id";
}

=head1 NAME

Catmandu::Bag::IdGenerator::Incremental - an incremental ID generator

=head1 CONFIGURATION

    # in config/store.yml
    main:
      package: DBI
      options:
        data_source: "DBI:mysql:database=librecat_main"
        username: xxx
        password: yyy
        bags:
          puiblication:
            plugins: ['Datestamps']
            id_generator: Incremental

=head1 SEE ALSO

L<Catmandu::Bag::IdGenerator>

=cut

1;
