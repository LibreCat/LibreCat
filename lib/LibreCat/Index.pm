package LibreCat::Index;

use Carp;

=head1 NAME

LibreCat::Index - checks status of current index and of index names

=head1 METHODS

=cut

use Catmandu::Sane;
use LibreCat::App::Helper;
use Search::Elasticsearch;
use Try::Tiny;

=head2 get_status()

Return a HASH containing active indexes and aliases:

    ---
    active_index: librecat1
    alias: librecat
    all_indices:
    - librecat1
    number_of_indices: 1
    ...
=cut
sub get_status {
    my ($self) = @_;

    my $ind_name = Catmandu->config->{store}->{search}->{options}->{index_name};
    my $ind1 = $ind_name ."1";
    my $ind2 = $ind_name ."2";

    my $e = Search::Elasticsearch->new();

    eval {
        $e->info;
    };
    if ($@) {
        warn $@;
        return undef;
    }

    my $ind_exists  = $e->indices->exists(index => $ind_name);
    my $ind1_exists = $e->indices->exists(index => $ind1);
    my $ind2_exists = $e->indices->exists(index => $ind2);

    my $alias_exists_for_1 = $e->indices->exists_alias(index => $ind1, name => $ind_name);
    my $alias_exists_for_2 = $e->indices->exists_alias(index => $ind2, name => $ind_name);

    my $result;
    $result->{all_indices} = [];
    push @{$result->{all_indices}}, $ind_name if ($ind_exists and !$alias_exists_for_1 and !$alias_exists_for_2);
    push @{$result->{all_indices}}, $ind1 if $ind1_exists;
    push @{$result->{all_indices}}, $ind2 if $ind2_exists;
    $result->{number_of_indices} = @{$result->{all_indices}};
    $result->{active_index} = $ind1 if ($ind1_exists and $alias_exists_for_1);
    $result->{active_index} = $ind2 if ($ind2_exists and $alias_exists_for_2);
    $result->{active_index} = $ind_name if (!$ind1_exists and !$ind2_exists and $ind_exists);
    $result->{alias} = $ind_name if ($alias_exists_for_1 or $alias_exists_for_2);

    return $result;
}

=head2 initialize()

Set up the search alias and indexes. This need to be executed at installation time.

=cut
sub initialize {
    my ($self) = @_;

    my $i_status = $self->get_status;

    my $e = Search::Elasticsearch->new();

    print "Remove alias " .  $i_status->{alias} . "...\n";
    try {
        $e->indices->update_aliases(
            body => {
                actions => [
                    { remove => { alias => $i_status->{alias}, index => $i_status->{active_index} }}
                ]
            }
        );
    }
    catch {
        print "Alias not present, but everything is still ok\n";
    };

    foreach my $index (@{$i_status->{all_indices}}){
        print "Removing index $index...\n";
        $e->indices->delete(index => $index);
    }

    # Create at least one record in the index in order to create an alias...
    my $ind_name = Catmandu->config->{store}->{search}->{options}->{index_name};
    my $ind1 = $ind_name ."1";
    my $index = Catmandu->store('search', index_name => $ind1)->bag('init');
    $index->add({'time' => time , date => scalar(localtime(time))});
    $index->commit;

    print "Creating alias $ind_name...\n";
    $e->indices->update_aliases(
        body => {
            actions => [
                { add => { alias => $ind_name, index => $ind1 }},
            ]
        }
    );

    print "Done\n";

    1;
}

=head2 switch()

Index all records and switch the alias to the new index

=cut
sub switch {
    my ($self) = @_;

    my $ind_name = Catmandu->config->{store}->{search}->{options}->{'index_name'};

    my $elastic_search = Search::Elasticsearch->new();

    my $i_status = LibreCat::Index->get_status;

    if (my $active = $i_status->{active_index}) {
        print  "Active index: $active...\n";

        if ($active =~ /([12])$/) {
            my $inactive = $active;
            $inactive =~ tr/12/21/;
            for my $ind (@{$i_status->{all_indices}}){
                next if $ind eq $active;
                print "Deleting: $ind\n";
                $elastic_search->indices->delete(index => $ind);
            }
            print "Switching: $active -> $inactive...\n";
            $self->_do_switch($active, $inactive, $elastic_search);
        }
        else {
            croak "Expecting $active\[12\] but found " . $i_status->{active_index} . " as active index";
        }
    }
    else {
        print "No active index found...\n";
        if($i_status->{all_indices} and $i_status->{number_of_indices}){
            for my $ind (@{$i_status->{all_indices}}){
                print "Deleting: $ind\n";
                $elastic_search->indices->delete(index => $ind);
            }
        }
        print "Switching: No index -> $ind_name\1..\n";
        $self->_do_switch("No index", $ind_name . 1, $elastic_search);
    }

    print "Done\n";

    return 0;
}

sub _do_switch {
    my ($self, $old, $new, $elastic_search) = @_;

    my $main_store = Catmandu->store('main');
    my $ind_name   = Catmandu->config->{store}->{search}->{options}->{index_name};

    print "$old is active, new index will be $new...\n";

    my $store = Catmandu->store('search', index_name => $new);

    my @bags = keys %{Catmandu->config->{store}->{search}->{options}->{bags}};

    for my $b (@bags) {
        print "Indexing $b...\n";
        my $bag = $store->bag($b);
        $bag->add_many($main_store->bag($b)->benchmark);
        $bag->commit;
    }

    print "New index is $new. Testing...\n";
    my $checkForIndex = $elastic_search->indices->exists(index => $new);
    my $checkForAlias = $elastic_search->indices->exists(index => $ind_name);

    if ($checkForIndex) {
        print "Index $new exists. Setting index alias $ind_name to $new and testing again.\n";

        if (!$checkForAlias) {
            # First run, no alias present
            $elastic_search->indices->update_aliases(
                body => {
                    actions => [
                        { add => { alias => $ind_name, index => $new }},
                    ]
                }
            );
        }
        else {
            $elastic_search->indices->update_aliases(
                body => {
                    actions => [
                        { add    => { alias => $ind_name, index => $new }},
                        { remove => { alias => $ind_name, index => $old }}
                    ]
                }
            );
        }

        $checkForIndex = $elastic_search->indices->exists(index => $ind_name);

        if ($checkForIndex) {
            # First run, no old index to be deleted
            print "Alias $ind_name is ok and points to index $new.\n";
        }
        else {
            print "Error: Could not create alias $ind_name.\n";
            exit;
        }
    }
    else {
        print "Error: Could not create index $new.\n";
        exit;
    }
}

1;
