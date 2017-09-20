package LibreCat::Cmd::department;

use Catmandu::Sane;
use LibreCat::App::Helper;
use LibreCat::Validator::Department;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat department [options] list [<cql-query>]
librecat department [options] export [<cql-query>]
librecat department [options] add <FILE>
librecat department [options] get <id>
librecat department [options] delete <id>
librecat department [options] valid <FILE>
librecay department [options] tree [<FILE>]

options:
    --sort=STR    (sorting results [only in combination with cql-query])
    --total=NUM   (total number of items to list/export)
    --start=NUM   (start list/export at this item)

E.g.

librecat department list 'layer = 1'
librecat department --sort "name,,1" list ""  # force to use an empty query

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (['total=i', ""], ['start=i', ""], ['sort=s', ""],);
}

sub opts {
    state $opts = $_[1];
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands = qr/list|export|get|add|delete|valid|tree/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    binmode(STDOUT, ":encoding(utf-8)");

    if ($cmd eq 'list') {
        return $self->_list(@$args);
    }
    elsif ($cmd eq 'export') {
        return $self->_export(@$args);
    }
    elsif ($cmd eq 'get') {
        return $self->_get(@$args);
    }
    elsif ($cmd eq 'add') {
        return $self->_add(@$args);
    }
    elsif ($cmd eq 'delete') {
        return $self->_delete(@$args);
    }
    elsif ($cmd eq 'valid') {
        return $self->_valid(@$args);
    }
    elsif ($cmd eq 'tree') {
        return $self->_tree(@$args);
    }
}

sub _list {
    my ($self, $query) = @_;

    my $sort  = $self->opts->{sort}  // undef;
    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it;

    if (defined($query)) {
        $it = LibreCat::App::Helper::Helpers->new->department->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        $it = Catmandu->store('main')->bag('department');
        $it = $it->slice($start // 0, $total)
            if (defined($start) || defined($total));
    }

    my $count = $it->each(
        sub {
            my ($item)  = @_;
            my $id      = $item->{_id};
            my $name    = $item->{name};
            my $display = $item->{display};
            my $layer   = $item->{layer};

            printf "%-2.2d %-40.40s %-40.40s %s\n", $layer, $id, $name,
                $display;
        }
    );

    print "count: $count\n";

    if (!defined($query) && defined($sort)) {
        print STDERR
            "warning: sort only active in combination with a query\n";
    }

    return 0;
}

sub _tree {
    my ($self, $file) = @_;

    if ($file) {
        $self->_tree_parse($file);
    }
    else {
        $self->_tree_display;
    }
}

sub _tree_parse {
    my ($self, $file) = @_;

    croak "usage: $0 tree <file>" unless defined($file) && -r $file;

    my $importer = Catmandu->importer('YAML', file => $file);
    my $HASH     = $importer->first;
    my $helper   = LibreCat::App::Helper::Helpers->new;

    print "deleting previous departments...\n";
    $helper->department->delete_all;

    my $index = $helper->department;

    _tree_parse_parser(
        $HASH->{tree},
        sub {
            my $rec = shift;
            LibreCat->hook('department-update-cmd')->fix_around(
                $rec,
                sub {
                    if ($rec->{_validation_errors}) {

                        # ...
                    }
                    else {
                        Catmandu->store('main')->bag('department')->add($rec);
                        $index->add($rec);
                    }
                }
            );
            print "added $rec->{_id}\n";
        }
    );

    $index->commit;
}

sub _tree_parse_parser {
    my $tree     = shift;
    my $callback = shift;
    my $layer    = shift // 1;
    my $parents  = shift // [];

    return unless $tree;

    for my $node (keys %{$tree}) {
        my $display = $tree->{$node}->{display};
        my $name    = $tree->{$node}->{name};

        $callback->(
            {
                _id     => $node,
                name    => $name,
                display => $display,
                layer   => $layer,
                tree    => $parents
            }
        );

        _tree_parse_parser($tree->{$node}->{tree},
            $callback, $layer + 1, [{_id => $node}, @$parents]);
    }
}

sub _tree_display {
    my $it   = Catmandu->store('main')->bag('department');
    my $HASH = {};

    $it->each(
        sub {
            my ($item) = @_;

            my $tree = $item->{tree} // [];

            my $root = $HASH;

            my @reversed = reverse @$tree;

            for my $node (@reversed) {
                my $id = $node->{_id};

                $root->{tree}->{$id} //= {};

                $root = $root->{tree}->{$id};
            }

            $root->{tree}->{$item->{_id}}->{name}    = $item->{name};
            $root->{tree}->{$item->{_id}}->{display} = $item->{display};
        }
    );

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add($HASH);
    $exporter->commit;

    return 0;
}

sub _export {
    my ($self, $query) = @_;

    my $sort  = $self->opts->{sort}  // undef;
    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it;

    if (defined($query)) {
        $it = LibreCat::App::Helper::Helpers->new->department->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        $it = Catmandu->store('main')->bag('department');
        $it = $it->slice($start // 0, $total)
            if (defined($start) || defined($total));
    }

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many($it);
    $exporter->commit;

    if (!defined($query) && defined($sort)) {
        print STDERR
            "warning: sort only active in combination with a query\n";
    }

    return 0;
}

sub _get {
    my ($self, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = Catmandu->store('main')->bag('department')->get($id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _add {
    my ($self, $file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret      = 0;
    my $importer = Catmandu->importer('YAML', file => $file);
    my $helper   = LibreCat::App::Helper::Helpers->new;
    my $bag      = Catmandu->store('main')->bag('department');

    my $records = $importer->select(
        sub {
            my $rec = $_[0];

            $rec->{_id} //= $bag->generate_id;

            my $is_ok = 1;

            LibreCat->hook('department-update-cmd')->fix_around(
                $rec,
                sub {
                    if ($rec->{_validation_errors}) {
                        print STDERR join("\n",
                            $rec->{_id},
                            "ERROR: not a valid department",
                            @{$rec->{_validation_errors}}),
                            "\n";
                        $ret   = 2;
                        $is_ok = 0;
                    }
                    else {
                        $bag->add($rec);
                    }
                }
            );

            return 0 unless $is_ok;

            print "added $rec->{_id}\n";

            return 1;
        }
    );

    my $index = $helper->department;
    $index->add_many($records);
    $index->commit;

    $ret;
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    # Deleting backup
    {
        my $bag = Catmandu->store('main')->bag('department');
        $bag->delete($id);
        $bag->commit;
    }

    # Deleting search
    {
        my $bag = LibreCat::App::Helper::Helpers->new->department;
        $bag->delete($id);
        $bag->commit;
    }

    print "deleted $id\n";
    return 0;
}

sub _valid {
    my ($self, $file) = @_;

    croak "usage: $0 valid <FILE>" unless defined($file) && -r $file;

    my $validator = LibreCat::Validator::Department->new;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->each(
        sub {
            my $item = $_[0];

            unless ($validator->is_valid($item)) {
                my $errors = $validator->last_errors();
                my $id = $item->{_id} // '';
                if ($errors) {
                    for my $err (@$errors) {
                        print STDERR "ERROR $id: $err\n";
                    }
                }
                else {
                    print STDERR "ERROR $id: not valid\n";
                }
                $ret = 2;
            }
        }
    );

    return $ret;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::department - manage librecat departments

=head1 SYNOPSIS

    librecat department list [<cql-query>]
    librecat department export [<cql-query>]
    librecat department add <FILE>
    librecat department get <id>
    librecat department delete <id>
    librecat department valid <FILE>
    librecat department tree [<FILE>]

    options:
        --sort=STR    (sorting results [only in combination with cql-query])
        --total=NUM   (total number of items to list/export)
        --start=NUM   (start list/export at this item)
=cut
