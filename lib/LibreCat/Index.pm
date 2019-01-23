package LibreCat::Index;

use Catmandu::Sane;

=head1 NAME

LibreCat::Index - checks status of current index and of index names

=head1 METHODS

=head2 new()

Create a new instance of LibreCat::Index

=cut

use Carp;
use Catmandu;
use Catmandu::Util qw(require_package);
use LibreCat qw(fixer);
use Clone qw(clone);
use Try::Tiny;
use Moo;
use POSIX qw(strftime);
use namespace::clean;

has main_store => (is => 'lazy');
has search_store => (is => 'lazy');
has search_store_1 => (is => 'lazy');
has search_store_2 => (is => 'lazy');
has es => (is => 'lazy');
has indices => (is => 'lazy');

sub _build_main_store {
    Catmandu->store('main');
}

sub _build_search_store {
    Catmandu->store('search');
}

sub _build_search_store_1 {
    $_[0]->_build_search_store_n(1);
}

sub _build_search_store_2 {
    $_[0]->_build_search_store_n(2);
}

sub _build_search_store_n {
    my ($self, $n) = @_;
    my $conf = Catmandu->config->{store}{search};
    my $pkg  = $conf->{package};
    my $opts = clone($conf->{options});
    my $bags = $opts->{bags};
    for my $bag (keys %$bags) {
        my $bag_opts = $bags->{$bag};
        my $index = $bag_opts->{index} // $bag;
        $bag_opts->{index} = "${index}_${n}";
    }
    require_package($pkg, 'Catmandu::Store')->new($opts);
}

sub _build_es {
    $_[0]->search_store->es;
}

sub _build_indices {
    my $bags = Catmandu->config->{store}{search}{options}{bags};
    [map {
            my $bag = $_;
            my $index = $bags->{$bag}{index} // $bag;
            +{ bag => $bag,
               alias => $index,
               index => $index,
               index_1 => "${index}_1",
               index_2 => "${index}_2", };
    } keys %$bags];
}

=head2 is_available()

Returns true if the server is up and running.

=cut

sub is_availabe {
    my ($self) = @_;

    eval {$self->es->info; 1} || return 0;
    1;
}

=head2 active

Return the active index

=cut

sub active {
    my ($self) = @_;

    my $status = $self->status;

    if (my $active = $status->{active_index}) {
        if ($self->index1->{index_name} eq $active) {
            return {active => $self->index1, inactive => $self->index2};
        }
        else {
            return {active => $self->index2, inactive => $self->index1};
        }
    }

    return undef;
}

=head2 has_index($name)

Return true when an index exists

=cut

sub has_index {
    my ($self, $index) = @_;
    $self->es->indices->exists(index => $index);
}

=head2 has_alias($index, $alias)

Return true when an alias exists

=cut

sub has_alias {
    my ($self, $index, $alias) = @_;
    $self->es->indices->exists_alias(index => $index, name => $alias);
}

=head2 create_alias($index, $alias)

Create an alias for $index

=cut

sub create_alias {
    my ($self, $index, $alias) = @_;
    $self->es->indices->update_aliases(body =>
            {actions => [{add => {index => $index, alias => $alias}}]});
}

=head2 remove_alias($index, $alias)

Remove the alias for $index

=cut

sub remove_alias {
    my ($self, $index, $alias) = @_;
    my $ok = 1;
    if ($self->es->indices->exists(index => $index)) {
        try {
            $self->es->indices->update_aliases(
                body => {
                    actions =>
                        [{remove => {index => $index, alias => $alias}}]
                }
            );
        }
        catch {
            $ok = 0;
        };
    }
    $ok;
}

=head2 remove_index($index)

Remove the alias for $index

=cut

sub remove_index {
    my ($self, $index) = @_;
    if ($self->es->indices->exists(index => $index)) {
        $self->es->indices->delete(index => $index);
        return 1;
    }
    0;
}

=head2 remove_index($name)

Remove the alias for $name

=cut

sub remove_all {
    my ($self, $name) = @_;
    my $index1_name = $self->index1->{index_name};
    my $index2_name = $self->index2->{index_name};

    my $ret;

    $ret += $self->remove_index($index1_name);
    $ret += $self->remove_index($index2_name);

    $ret > 0;
}

=head2 touch_index($index)

Make sure $index exists.

=cut

sub touch_index {
    my ($self, $index) = @_;
    my ($info) = grep { $_->{index} eq $index } @{$self->indices};
    $self->search_store_1->bag($info->{bag})->get('¯\_(ツ)_/¯');
    $self->search_store_2->bag($info->{bag})->get('¯\_(ツ)_/¯');
}

sub status_for {
    my ($self, $info) = @_;

    my $status = {};

    my $index_exists   = $self->has_index($info->{index});
    my $index_1_exists = $self->has_index($info->{index_1});
    my $index_2_exists = $self->has_index($info->{index_2});
    my $alias_1_exists = $self->has_alias($info->{index_1}, $info->{alias});
    my $alias_2_exists = $self->has_alias($info->{index_2}, $info->{alias});

    $status->{configured_index_name} = $info->{index};
    $status->{all_indices} = [];
    push @{$status->{all_indices}}, $info->{index}
        if $index_exists && !$alias_1_exists && !$alias_2_exists;
    push @{$status->{all_indices}}, $info->{index_1} if $index_1_exists;
    push @{$status->{all_indices}}, $info->{index_2} if $index_2_exists;
    $status->{number_of_indices} = @{$status->{all_indices}};
    $status->{active_index} = $info->{index_1} if $index_1_exists && $alias_1_exists;
    $status->{active_index} = $info->{index_2} if $index_2_exists && $alias_2_exists;
    $status->{active_index} = $info->{index}
        if !$index_1_exists && !$index_2_exists && $index_exists;
    $status->{alias} = $info->{alias}
        if $alias_1_exists || $alias_2_exists;

    $status;
}

=head2 status()

Return a HASH containing active indexes and aliases:

    ---
    active_index: librecat1
    alias: librecat
    all_indices:
    - librecat1
    number_of_indices: 1
    ...

=cut

sub status {
    my ($self) = @_;

    $self->is_availabe || return;

    [map { $self->status_for($_) } @{$self->indices}];
}

=head2 initialize()

Set up the search alias and indexes. This need to be executed at installation time.

=cut

sub initialize {
    my ($self) = @_;

    for my $info (@{$self->indices}) {
        my $status = $self->status_for($info) || return 0;

        if ($status->{active_index}) {
            $self->remove_alias($status->{active_index}, $info->{alias});
            say "Removed alias $info->{alias} for $info->{index}...";
        }
        else {
            say "Alias for $info->{index} not present, but everything is still ok";
        }

        for my $index (@{$status->{all_indices}}) {
            say "Removing index $index...";
            $self->remove_index($index);
        }

        $self->touch_index($info->{index});

        say "Creating alias $info->{alias} for $info->{index_1}...";
        $self->create_alias($info->{index_1}, $info->{alias});

        say "Done";
    }

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

        $ret = $self->_do_index($active->{inactive})
            && $self->_do_switch($active->{active}, $active->{inactive});
    }
    else {
        print "No active index found...\n";

        $self->remove_index($self->index1->{index_name});
        $self->remove_index($self->index2->{index_name});

        $self->touch_index;

        print "Switching: No index -> "
            . $self->index1->{index_name} . "..\n";

        $ret = $self->_do_index($self->index1)
            && $self->_do_switch(undef, $self->index1);
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
    my ($self, $new) = @_;

    my $new_name = $new->{index_name};
    my @bags = keys %{Catmandu->config->{store}->{search}->{options}->{bags}};

    try {
        my $now = strftime "%Y-%m-%dT%H:%M:%SZ", gmtime(time);

        print "Index starts at: $now\n";

        # First index all records from the main database...
        for my $b (@bags) {
            print "Indexing $b into $new_name...\n";
            my $fixer = fixer("index_$b.fix");
            my $bag   = $new->bag($b);
            $bag->add_many($fixer->fix($self->main->bag($b)->benchmark));
            $bag->commit;
        }

        # Check for records changed during the previous indexation...
        my $has_changes;
        do {
            $has_changes = 0;

            print "Checking index for updates changed since $now ...\n";
            for my $b (@bags) {
                print "Checking $b ...\n";
                my $bag   = $new->bag($b);
                my $fixer = fixer("index_$b.fix");
                my $it
                    = $self->main_index->bag($b)
                    ->searcher(
                    query => {range => {date_updated => {gte => $now}}});
                $it->each(
                    sub {
                        my $item         = $_[0];
                        my $id           = $item->{_id};
                        my $date_updated = $item->{date_updated};
                        my $rec          = $self->main->bag($b)->get($id);

                        if ($rec) {
                            print "Adding $id changed on $date_updated\n";
                            $bag->add($fixer->fix($rec));
                        }
                        else {
                            carp "main database lost id `$id'?";
                        }

                        $has_changes = 1;
                    }
                );

                $bag->commit;

                $now = strftime "%Y-%m-%dT%H:%M:%SZ", gmtime(time);
            }
        } while ($has_changes);
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
        print
            "Index $new_name exists. Setting index alias $alias_name to $new_name and testing again.\n";

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
