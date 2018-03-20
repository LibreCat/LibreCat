package LibreCat::Model;

use Catmandu::Sane;
use Catmandu::Util qw(is_string is_code_ref is_able);
use List::Util qw(pairs);
use Moo::Role;
use namespace::clean;

with 'LibreCat::Logger';

has bag => (is => 'ro', required => 1, handles => 'Catmandu::Iterable');
has search_bag =>
    (is => 'ro', required => 1, handles => [qw(search searcher)]);
has validator =>
    (is => 'ro', required => 1, handles => [qw(is_valid whitelist)]);
has before_add => (is => 'lazy');

sub _build_before_add {
    [whitelist => 'apply_whitelist'];
}

sub prepend_before_add {
    my $self = shift;
    unshift @{$self->before_add}, @_;
}

sub append_before_add {
    my $self = shift;
    push @{$self->before_add}, @_;
}

sub BUILD {
    my ($self, $opts) = @_;
    for my $method (qw(prepend_before_add append_before_add)) {
        if (my $hooks = $opts->{$method}) {
            $self->$method(@$hooks);
        }
    }
}

sub generate_id {
    $_[0]->bag->generate_id;
}

sub get {
    my ($self, $id) = @_;
    $self->bag->get($id);
}

sub add_many {
    my ($self, $recs, %opts) = @_;
    $recs->each(
        sub {
            $self->add($_[0], %opts, skip_commit => 1);
        }
    );
    $self->bag->commit;
    $self->search_bag->commit;

    # TODO return value
}

sub add {
    my ($self, $rec, %opts) = @_;

    # TODO do we really need an id even before validation?
    $rec->{_id} //= $self->generate_id;

    $rec = $self->apply_hooks_to_record($self->before_add, $rec,
        skip => $opts{skip_before_add});

    if ($self->is_valid($rec)) {
        $self->_store($rec, %opts);
        $self->_index($rec, %opts);
    }
    elsif ($opts{on_validation_error}) {
        $opts{on_validation_error}->($rec);
    }

    $rec;
}

sub delete {
    my ($self, $id, %opts) = @_;
    $self->purge($id, %opts);
}

sub _store {
    my ($self, $rec, %opts) = @_;

    $self->bag->add($rec);
    $self->bag->commit unless $opts{skip_commit};
}

sub _index {
    my ($self, $rec, %opts) = @_;

    if ($self->log->is_debug) {
        my $bag_name = $self->search_bag->name;
        $self->log->debugf("indexing record in %s: %s", $bag_name, $rec);
    }

    $rec = $self->search_bag->add($rec);
    $self->search_bag->commit unless $opts{skip_commit};

    sleep 1 unless $opts{skip_commit};    # TODO move to controller

    $rec;
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
