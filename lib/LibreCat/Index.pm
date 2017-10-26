package LibreCat::Index;

use Carp;

=head1 NAME

LibreCat::Index - checks status of current index and of index names

=head1 METHODS

=head2 new()

Create a new instance of LibreCat::Index

=cut

use Catmandu::Sane;
use Catmandu::Util;
use LibreCat::App::Helper;
use Search::Elasticsearch;
use Try::Tiny;
use Moo;

has main    => (is => 'lazy');
has alias   => (is => 'lazy');
has index1  => (is => 'lazy');
has index2  => (is => 'lazy');
has es      => (is => 'lazy');

sub _build_main {
    Catmandu->store('main');
}

sub _build_alias {
    Catmandu->config->{store}->{search}->{options}->{index_name};
}

# Use an explicit require_package->new to create instances of index1
# and index2. The standard Catmandu->store('search',%opts) will cache
# connections to the EL store, which can't be overwritten by a second
# call to Catmandu->store('search',%opts) with other options.
sub _build_index1 {
    my $conf    = Catmandu->config->{store}->{search};
    my $package = $conf->{package};
    my $opts    = $conf->{options};
    my $ns      = 'Catmandu::Store';
    Catmandu::Util::require_package($package, $ns)->new(%$opts, index_name => $opts->{index_name} . 1);
}

sub _build_index2 {
    my $conf    = Catmandu->config->{store}->{search};
    my $package = $conf->{package};
    my $opts    = $conf->{options};
    my $ns      = 'Catmandu::Store';
    Catmandu::Util::require_package($package, $ns)->new(%$opts, index_name => $opts->{index_name} . 2);
}

sub _build_es {
    Search::Elasticsearch->new();
}

=head2 is_available()

Return true when the index is up and running.

=cut
sub is_availabe {
    my ($self) = @_;

    eval {
        $self->es->info;
    };
    if ($@) {
        return undef;
    }

    return 1;
}

=head2 active

Return the active index

=cut
sub active {
    my ($self) = @_;

    my $i_status = $self->get_status;

    if (my $active = $i_status->{active_index}) {
        if ($self->index1->{index_name} eq $active ) {
            return {
                active   => $self->index1 ,
                inactive => $self->index2
            };
        }
        else {
            return {
                active   => $self->index2 ,
                inactive => $self->index1
            };
        }
    }

    return undef;
}

=head2 has_index($name)

Return true when an index exists

=cut
sub has_index {
    my ($self,$name) = @_;
    return $self->es->indices->exists(index => $name);
}

=head2 has_alias($name)

Return true when an alias exists

=cut
sub has_alias {
    my ($self,$name) = @_;
    my $alias_name = $self->alias;
    return $self->es->indices->exists_alias(index => $name, name => $alias_name);
}

=head2 create_alias($name)

Create an alias for $name

=cut
sub create_alias {
    my ($self,$name) = @_;
    my $alias_name = $self->alias;
    $self->es->indices->update_aliases(
        body => {
            actions => [
                { add => { alias => $alias_name, index => $name }},
            ]
        }
    );
}

=head2 remove_alias($name)

Remove the alias for $name

=cut
sub remove_alias {
    my ($self,$name) = @_;
    my $alias_name = $self->alias;
    if ($self->es->indices->exists(index => $name)) {
        try {
            $self->es->indices->update_aliases(
                body => {
                    actions => [
                        { remove => { alias => $alias_name, index => $name }}
                    ]
                }
            );
            return 1;
        }
        catch {
            return 0;
        };
    }
    else {
        return 1;
    }
}

=head2 remove_index($name)

Remove the alias for $name

=cut
sub remove_index {
    my ($self,$name) = @_;
    if ($self->es->indices->exists(index => $name)) {
        $self->es->indices->delete(index => $name);
        return 1
    }
    else {
        return 0;
    }
}

=head2 remove_index($name)

Remove the alias for $name

=cut
sub remove_all {
    my ($self,$name) = @_;
    my $index1_name = $self->index1->{index_name};
    my $index2_name = $self->index2->{index_name};

    my $ret;

    $ret += $self->remove_index($index1_name);
    $ret += $self->remove_index($index2_name);

    $ret > 0;
}


=head2 touch_index($name)

Create a sample record for the indexes.

=cut
sub touch_index {
    my ($self,$name) = @_;
    my $index1 = $self->index1->bag('init');
    $index1->add({'time' => time , date => scalar(localtime(time))});
    $index1->commit;

    my $index2 = $self->index2->bag('init');
    $index2->add({'time' => time , date => scalar(localtime(time))});
    $index2->commit;
}

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

    my $ind_name = $self->alias;
    my $ind1     = $self->index1->{index_name};
    my $ind2     = $self->index2->{index_name};

    return unless $self->is_availabe();

    my $ind_exists  = $self->has_index($ind_name);
    my $ind1_exists = $self->has_index($ind1);
    my $ind2_exists = $self->has_index($ind2);

    my $alias_exists_for_1 = $self->has_alias($ind1);
    my $alias_exists_for_2 = $self->has_alias($ind2);

    my $result;

    $result->{configured_index_name}  = $ind_name;
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

    my $status = $self->get_status;

    if ($status->{active_index}) {
        $self->remove_alias($status->{active_index});
        print "Removed alias " .  $status->{alias} . "...\n";
    }
    else {
        print "Alias not present, but everything is still ok\n";
    }

    foreach my $index (@{$status->{all_indices}}){
        print "Removing index $index...\n";
        $self->remove_index($index);
    }

    # Create at least one record in the index in order to create an alias...
    $self->touch_index;

    my $alias_name  = $self->alias;
    my $index1_name = $self->index1->{index_name};

    print "Creating alias $index1_name...\n";
    $self->create_alias($index1_name);

    print "Done\n";

    1;
}

=head2 switch()

Index all records and switch the alias to the new index

=cut
sub switch {
    my ($self) = @_;

    my $alias_name = $self->alias;

    my $ret;

    if (my $active = $self->active) {
        my $active_name   = $active->{active}->{index_name};
        my $inactive_name = $active->{inactive}->{index_name};

        print "Active index: $active_name...\n";

        print "Deleting: $inactive_name...\n";

        $self->remove_index($inactive_name);

        $self->touch_index;

        $ret =  $self->_do_index($active->{inactive}) &&
                $self->_do_switch($active->{active},$active->{inactive});
    }
    else {
        print "No active index found...\n";

        $self->remove_index($self->index1->{index_name});
        $self->remove_index($self->index2->{index_name});

        $self->touch_index;

        print "Switching: No index -> " . $self->index1->{index_name} . "..\n";

        $ret =  $self->_do_index($self->index1) &&
                $self->_do_switch(undef, $self->index1);
    }

    if ($ret) {
        print "Done\n";
        return 1;
    }
    else {
        print "Failed\n";
        return undef;
    }
}

sub _do_index {
    my ($self,$new) = @_;

    my $new_name = $new->{index_name};
    my @bags = keys %{Catmandu->config->{store}->{search}->{options}->{bags}};

    try {
        for my $b (@bags) {
            print "Indexing $b into $new_name...\n";
            my $bag = $new->bag($b);
            $bag->add_many($self->main->bag($b)->benchmark);
            $bag->commit;
        }
    }
    catch {
        print STDERR "Failed to create the index $new_name";
        warn $_;
        return 0;
    };

    1;
}

sub _do_switch {
    my ($self, $old, $new) = @_;

    my $alias_name = $self->alias;
    my $old_name   = $old->{index_name};
    my $new_name   = $new->{index_name};

    print "New index is $new_name. Testing...\n";
    my $checkForIndex = $self->has_index($new_name);
    my $checkForAlias = $self->has_alias($new_name);

    if ($checkForIndex) {
        print "Index $new_name exists. Setting index alias $alias_name to $new_name and testing again.\n";

        $self->remove_alias($old_name);
        $self->create_alias($new_name);

        $checkForAlias = $self->has_alias($new_name);

        if ($checkForAlias) {
            # First run, no old index to be deleted
            print "Alias $alias_name is ok and points to index $new_name.\n";
        }
        else {
            print "Error: Could not create alias $alias_name.\n";
            return undef;
        }
    }
    else {
        print "Error: Could not create index $new_name.\n";
        return undef;
    }

    return 1;
}

1;
