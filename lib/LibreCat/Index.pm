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

=head2 active($index)

Return the active index

=cut

sub active {
    my ($self, $index) = @_;

    my $status = $self->status_for($index);

    if (my $active = $status->{active_index}) {
        my ($info) = grep { $_->{index} eq $index } @{$self->indices};

        if ($active eq $info->{index_1}) {
            return {active => $info->{index_1}, inactive => $info->{index_2}, active_n => 1, inactive_n => 2};
        }
        else {
            return {active => $info->{index_2}, inactive => $info->{index_1}, active_n => 2, inactive_n => 1};
        }
    }

    return;
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

Remove index $index

=cut

sub remove_index {
    my ($self, $index) = @_;
    if ($self->es->indices->exists(index => $index)) {
        $self->es->indices->delete(index => $index);
        return 1;
    }
    0;
}

=head2 purge($alias)

Remove the alias and it's associated indexes

=cut

sub purge {
    my ($self, $index) = @_;

    my $status = $self->status_for($index) || return 0;

    if ($status->{active_index}) {
        $self->remove_alias($status->{active_index}, $index);
    }
    for (@{$status->{all_indices}}) {
        $self->remove_index($_);
    }

    1;
}

=head2 purge_all()

Remove all aliases and indexes

=cut

sub purge_all {
    my ($self) = @_;

    my $ok = 1;

    for my $info (@{$self->indices}) {
        $ok = 0 unless $self->purge($info->{index});
    }

    $ok;
}

=head2 touch_index($index)

Make sure $index exists.

=cut

sub touch_index {
    my ($self, $index) = @_;

    my ($info) = grep { $_->{index} eq $index } @{$self->indices};

    $self->search_store_1->bag($info->{bag})->create_index;
    $self->search_store_2->bag($info->{bag})->create_index;

    1;
}

sub status_for {
    my ($self, $index) = @_;

    my ($info) = grep { $_->{index} eq $index } @{$self->indices};

    my $status = {};

    my $index_exists   = $self->has_index($info->{index});
    my $index_1_exists = $self->has_index($info->{index_1});
    my $index_2_exists = $self->has_index($info->{index_2});
    my $alias_1_exists = $self->has_alias($info->{index_1}, $info->{index});
    my $alias_2_exists = $self->has_alias($info->{index_2}, $info->{index});

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
    $status->{alias} = $info->{index}
        if $alias_1_exists || $alias_2_exists;

    $status;
}

=head2 status()

Returns hashes containing active indexes and aliases:

    ---
    active_index: librecat_publication_1
    alias: librecat_publication
    all_indices:
    - librecat_publication_1
    number_of_indices: 1
    ...
    ---
    active_index: librecat_user_1
    alias: librecat_user
    all_indices:
    - librecat_user_1
    number_of_indices: 1
    ...

=cut

sub status {
    my ($self) = @_;

    $self->is_availabe || return;

    [map { $self->status_for($_->{index}) } @{$self->indices}];
}

=head2 initialize()

Set up the search alias and indexes. This needs to be executed at installation time.

=cut

sub initialize {
    my ($self) = @_;

    for my $info (@{$self->indices}) {
        my $status = $self->status_for($info->{index}) || return 0;

        if ($status->{active_index}) {
            $self->remove_alias($status->{active_index}, $info->{index});
            say "Removed alias $info->{index} for $status->{active_index}...";
        }
        else {
            say "Alias for $info->{index} not present, but everything is still ok";
        }

        for my $index (@{$status->{all_indices}}) {
            say "Removing index $index...";
            $self->remove_index($index);
        }

        $self->touch_index($info->{index});

        say "Creating alias $info->{index} for $info->{index_1}...";
        $self->create_alias($info->{index_1}, $info->{index});

        say "Done";
    }

    1;
}

=head2 switch($index)

Reindex a store and switch the alias to the new index

=cut

sub switch {
    my ($self, $index) = @_;

    my ($info) = grep { $_->{index} eq $index } @{$self->indices};

    my $ret;

    if (my $active = $self->active($index)) {

        say "Active index: $active->{active}...";

        say "Deleting: $active->{inactive}...";

        $self->remove_index($active->{inactive});

        $self->touch_index($index);

        $ret = $self->_do_index($info, $active->{inactive_n})
            && $self->_do_switch($index, $active->{active}, $active->{inactive});
    }
    else {
        say "No active index found...";
        $self->remove_index($info->{index_1});
        $self->remove_index($info->{index_2});

        $self->touch_index($index);

        say "Switching: No index -> $info->{index_1}...";

        $ret = $self->_do_index($info, 1)
            && $self->_do_switch($index, undef, $info->{index_1});
    }

    if ($ret) {
        say "Done";
        return 1;
    }
    say "Failed";
    0;
}

=head2 switch_all()

Reindex all stores and switch the aliases

=cut

sub switch_all {
    my ($self) = @_;

    my $ok = 1;

    for my $info (@{$self->indices}) {
        $ok = 0 unless $self->switch($info->{index});
    }

    $ok;
}

sub _do_index {
    my ($self, $info, $n) = @_;

    my $index = $n == 1 ? $info->{index_1} : $info->{index_2};
    my $store_n = $n == 1 ? $self->search_store_1 : $self->search_store_2;
    my $bag_n = $store_n->bag($info->{bag});
    my $bag = $self->search_store->bag($info->{bag});
    my $main_bag = $self->main_store->bag($info->{bag});
    my $fixer = fixer("index_$info->{bag}.fix");

    my $ok = 1;

    try {
        my $now = strftime "%Y-%m-%dT%H:%M:%SZ", gmtime(time);

        say "Index starts at: $now";
        say "Indexing $info->{bag} into $index...";

        $bag_n->add_many($fixer->fix($main_bag->benchmark));
        $bag_n->commit;
        # Check for records changed during the previous indexation...
        my $has_changes;
        do {
            $has_changes = 0;

            say "Checking index for updates changed since $now...";
            say "Checking $info->{bag}...";

            my $it = $bag->searcher(query => {range => {date_updated => {gte => $now}}});
            $it->each(
                sub {
                    my $item         = $_[0];
                    my $id           = $item->{_id};
                    my $date_updated = $item->{date_updated};
                    my $rec          = $main_bag->get($id);

                    if ($rec) {
                        say "Adding $id changed on $date_updated";
                        $bag_n->add($fixer->fix($rec));
                    }
                    else {
                        carp "main database lost id '$id'?";
                    }

                    $has_changes = 1;
                }
            );

            $bag_n->commit;
            $now = strftime "%Y-%m-%dT%H:%M:%SZ", gmtime(time);
        } while ($has_changes);
    }
    catch {
        say STDERR "Failed to create the index $index";
        warn $_;
        $ok = 0;
    };

    $ok;
}

sub _do_switch {
    my ($self, $alias, $old_index, $new_index) = @_;

    say "New index is $new_index. Testing...";
    my $index_ok = $self->has_index($new_index);
    my $alias_ok = $self->has_alias($new_index, $alias);

    if ($index_ok) {
        say
            "Index $new_index exists. Setting index alias $alias to $new_index and testing again.";

        $self->remove_alias($old_index, $alias);
        $self->create_alias($new_index, $alias);

        $alias_ok = $self->has_alias($new_index, $alias);

        if ($alias_ok) {
            # First run, no old index to be deleted
            say "Alias $alias is ok and points to index $new_index.";
        }
        else {
            say "Error: Could not create alias $alias.";
            return 0;
        }
    }
    else {
        say "Error: Could not create index $new_index.";
        return 0;
    }

    1;
}

1;
