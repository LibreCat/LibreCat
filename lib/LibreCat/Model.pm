package LibreCat::Model;

use Catmandu::Sane;
use Catmandu::Util qw(is_string is_code_ref is_able);
use List::Util qw(pairs);
use Types::Standard qw(ConsumerOf);
use LibreCat::Types qw(+Pairs);
use Moo::Role;
use namespace::clean;

with 'Catmandu::Pluggable', 'LibreCat::Logger';

has bag => (
    is       => 'ro',
    required => 1,
    handles  => 'Catmandu::Iterable',
    isa      => ConsumerOf ['Catmandu::Bag']
);
has search_bag => (
    is       => 'ro',
    required => 1,
    handles  => [qw(search searcher)],
    isa      => ConsumerOf ['Catmandu::Bag', 'Catmandu::Searchable']
);
has validator => (
    is       => 'ro',
    required => 1,
    handles  => [qw(is_valid whitelist)],
    isa      => ConsumerOf ['LibreCat::Validator']
);
has before_add   => (is => 'lazy', init_arg => undef, isa => Pairs);
has before_index => (is => 'lazy', init_arg => undef, isa => Pairs);

sub plugin_namespace {
    'LibreCat::Model::Plugin';
}

sub _build_before_add {
    [whitelist => 'apply_whitelist'];
}

sub _build_before_index {
    [];
}

sub prepend_before_add {
    my ($self, $hooks) = @_;
    assert_Pairs($hooks);
    unshift @{$self->before_add}, @$hooks;
}

sub append_before_add {
    my ($self, $hooks) = @_;
    assert_Pairs($hooks);
    push @{$self->before_add}, @$hooks;
}

sub prepend_before_index {
    my ($self, $hooks) = @_;
    assert_Pairs($hooks);
    unshift @{$self->before_index}, @$hooks;
}

sub append_before_index {
    my ($self, $hooks) = @_;
    assert_Pairs($hooks);
    push @{$self->before_index}, @$hooks;
}

sub BUILD { }

before BUILD => sub {
    my ($self, $opts) = @_;

    for my $method (
        qw(prepend_before_add append_before_add prepend_before_index append_before_index)
        )
    {
        if (my $hooks = $opts->{$method}) {
            $self->$method($hooks);
        }
    }
};

sub generate_id {
    $_[0]->bag->generate_id;
}

sub get {
    my ($self, $id) = @_;
    $self->bag->get($id);
}

sub add_many {
    my ($self, $recs, %opts) = @_;
    my $n = 0;

    $recs->each(
        sub {
            $n += $self->add($_[0], %opts, skip_commit => 1);
        }
    );
    $self->bag->commit;
    $self->search_bag->commit;

    $n;
}

sub add {
    my ($self, $rec, %opts) = @_;

    # TODO do we really need an id even before validation?
    $rec->{_id} //= $self->generate_id;

    $rec = $self->apply_hooks_to_record($self->before_add, $rec,
        skip => $opts{skip_before_add});

    if ($self->is_valid($rec)) {
        $self->store($rec, %opts);
        $self->index($rec, %opts) unless $opts{skip_index};
        $opts{on_success}->($rec) if $opts{on_success};

        return 1;
    }
    elsif ($opts{on_validation_error}) {
        $opts{on_validation_error}->($rec, $self->validator->last_errors);
    }
    else {
        $self->log->errorf(
            "record %s has errors no `on_validation_error` set: %s"
                , $rec->{_id}
                , $self->validator->last_errors);
    }

    0;
}

sub delete_all {
    my ($self, %opts) = @_;
    $self->purge_all(%opts);
}

sub delete {
    my ($self, $id, %opts) = @_;
    $self->purge($id, %opts);
}

sub store {
    my ($self, $rec, %opts) = @_;

    $self->bag->add($rec);
    $self->bag->commit unless $opts{skip_commit};
    $rec;
}

# TODO get from bag if rec is an id
sub index {
    my ($self, $rec, %opts) = @_;

    $rec = $self->apply_hooks_to_record($self->before_index, $rec,
        skip => $opts{skip_before_index});

    if ($self->log->is_debug) {
        my $bag_name = $self->search_bag->name;
        $self->log->debugf("indexing record in %s: %s", $bag_name, $rec);
    }

    $rec = $self->search_bag->add($rec);
    $self->search_bag->commit unless $opts{skip_commit};

    sleep 1 unless $opts{skip_commit};    # TODO move to controller

    $rec;
}

sub purge_all {
    my ($self, %opts) = @_;

    $self->bag->delete_all;
    $self->bag->commit unless $opts{skip_commit};

    $self->search_bag->delete_all;
    $self->search_bag->commit unless $opts{skip_commit};

    sleep 1 unless $opts{skip_commit};    # TODO move to controller

    1;
}

sub purge {
    my ($self, $id, %opts) = @_;

    return unless $self->get($id);

    $self->bag->delete($id);
    $self->bag->commit unless $opts{skip_commit};

    $self->search_bag->delete($id);
    $self->search_bag->commit unless $opts{skip_commit};

    sleep 1 unless $opts{skip_commit};    # TODO move to controller

    $id;
}

sub commit {
    my ($self) = @_;
    $self->bag->commit;
    $self->search_bag->commit;

    1;
}

# TODO compile this
sub apply_hooks_to_record {
    my ($self, $hooks, $rec, %opts) = @_;

    for my $pair (pairs @$hooks) {
        my ($name, $hook) = @$pair;
        next if $opts{skip} && grep {$_ eq $name} @{$opts{skip}};
        if (is_string($hook)) {
            $rec = $self->$hook($rec);
        }
        elsif (is_able($hook, 'fix')) {
            $rec = $hook->fix($rec);
        }
    }

    $rec;
}

sub apply_whitelist {
    my ($self, $rec) = @_;
    my $whitelist = $self->whitelist;
    for my $key (keys %$rec) {
        unless (grep {$_ eq $key} @$whitelist) {
            $self->log->debug("deleting invalid key: $key");
            delete $rec->{$key};
        }
    }
    $rec;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Model - Base role for LibreCat models

=head1 CONFIGURATION

=head2 bag

The main store for this model. Required and must be a L<Catmandu::Bag>.

=head2 search_bag

The index for this model. Required and must be a L<Catmandu::Bag> and a L<Catmandu::Searchable>.

=head2 validator

The validator for this model. Required and must be a L<LibreCat::Validator>.

=head2 prepend_before_add

Add hooks that will be executed before a record is added.

=head2 append_before_add

Add hooks that will be executed before a record is added.

=head2 prepend_before_index

Add hooks that will be executed before a record is indexed.

=head2 append_before_index

Add hooks that will be executed before a record is indexed.

=head1 METHODS

All L<Catmandu::Iterable> methods as well as C<search> and C<searcher> from
L<Catmandu::Searchable> are available. This role also adds the following
methods:

=head2 generate_id

Generate and return a new id that is unique to this model.

=head2 get($id)

Returns the record identified by C<$id> if it exists, C<undef> otherwise.

=head2 add_many($iterator, %opts)

Add all the records in C<$iterator>. $<iterator> must be a
L<Catmandu::Iterator>. Returns the number of records that passed
validation and were succesfully added.

Using this method is more efficient than
successively calling C<add> for each record in the iterator.

Possible options:

=over

=item *

C<skip_before_add>: You can supply an arrayref of hook names that will not be executed.

    $model->add($rec, skip_before_add => ['whitelist']);

=item *

C<skip_index>: The record will be added to the main store but not indexed if
this option is C<1>.

=item *

C<on_success>: You can supply a callback function that will be called
with the record if the record was succesfully added.

=item *

C<on_validation_error>: You can supply a callback function that will be called
with the record and an arrayref of errors if validation fails.

=back

=head2 add($rec, %opts)

Insert or update the record identified by it's C<_id> key. If no C<_id> is given, a
new one will be generated for you. Returns C<1> if the record was valid and
succesfully stored and indexed, C<0> otherwise.

Any C<before_add> hooks will be applied before validation.

Options are the same as for C<add_many>, plus:

=over

=item *

C<skip_commit>: Changes will not be commited if this option is C<1>.

=back

=head2 delete_all(%opts)

Delete all records.

Options are:

=over

=item *

C<skip_commit>: Changes will not be commited if this option is C<1>.

=back

=head2 delete($id, %opts)

Delete the record identified by C<$id>. Returns C<$id> if the record was
deleted, C<undef> if no record was found.

Options are:

=over

=item *

C<skip_commit>: Changes will not be commited if this option is C<1>.

=back

=head2 store($rec, %opts)

This is a lower level method that inserts or updates the record in the main store. An
C<_id> is generated if none is given, but no validation is done. Returns the given C<$rec>.
You would normally use the higher level C<add> method.

Options are:

=over

=item *

C<skip_commit>: Changes will not be commited if this option is C<1>.

=back

=head2 index($rec)

Index the given record. An C<_id> is generated if none is given, but no
validation is done. Returns the given C<$rec>. You would normally use the
higher level C<add> method.

Options are:

=over

=item *

C<skip_commit>: Changes will not be commited if this option is C<1>.

=item *

C<skip_before_index>: You can supply an arrayref of hook names that will not be executed.

    $model->index($rec, skip_before_index => ['index_publication']);

=back

=head2 purge_all(%opts)

This is a lower level method that removes all records from the main store and the index. Always returns C<1>. You would normally use the
higher level C<delete_all> method.

Options are:

=over

=item *

C<skip_commit>: Changes will not be commited if this option is C<1>.

=back

=head2 purge($rec)

Remove the record identified by C<$id> from the main store and the index. Returns C<$id> if the record was
removed, C<undef> if no record was found.

Options are:

=over

=item *

C<skip_commit>: Changes will not be commited if this option is C<1>.

=back

=head2 commit

Commit any unsaved changes, for example after C<skip_commit => 1>. Always returns C<1>.

=head2 validator

Returns the validator for this model.

=head2 is_valid($rec)

Return 1 if the given C<$rec> is valid, C<0> otherwise.

=head2 whitelist

Returns all whitelisted field names for this model. Any fields not in this list
will be removed before adding the record. C<skip_before_filter> can be used to used to override this:

    $model->add($rec, skip_before_add => ['whitelist']);

=head2 bag

Return the onderlying main store for this model.

=head2 search_bag

Return the onderlying index for this model.

=head2 before_add

Returns the hooks that will be executed before a record is added.

=head2 prepend_before_add

Add hooks that will be executed before a record is added.

=head2 append_before_add

Add hooks that will be executed before a record is added.

=head2 before_index

Returns the hooks that will be executed before a record is indexed.

=head2 prepend_before_index

Add hooks that will be executed before a record is indexed.

=head2 append_before_index

Add hooks that will be executed before a record is indexed.

=head1 SEE ALSO

L<Catmandu::Iterable>, L<Catmandu::Searchable>

=cut
