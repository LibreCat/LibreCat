package LibreCat::Cmd::department;

use Catmandu::Sane;
use LibreCat qw(department);
use Path::Tiny;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat department list   [options] [<cql-query>]
librecat department export [options] [<cql-query>]
librecat department add    [options] <FILE>
librecat department get    [options] <id> | <IDFILE>
librecat department delete [options] <id> | <IDFILE>
librecat department valid  [options] <FILE>
librecat department tree   [options] [<FILE>]

options:
    --sort=STR    (sorting results [only in combination with cql-query])
    --total=NUM   (total number of items to list/export)
    --start=NUM   (start list/export at this item)

E.g.

librecat department list 'layer = 1'
librecat department list --sort "name,,1" ""  # force to use an empty query

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
        my $id = shift @$args;

        return $self->_on_all(
            $id,
            sub {
                $self->_get(shift);
            }
        );
    }
    elsif ($cmd eq 'add') {
        return $self->_add(@$args);
    }
    elsif ($cmd eq 'delete') {
        my $id = shift @$args;

        return $self->_on_all(
            $id,
            sub {
                $self->_delete(shift);
            }
        );
    }
    elsif ($cmd eq 'valid') {
        return $self->_valid(@$args);
    }
    elsif ($cmd eq 'tree') {
        return $self->_tree(@$args);
    }
}

sub _on_all {
    my ($self, $id_file, $callback) = @_;

    if (-r $id_file) {
        my $r = 0;
        for (path($id_file)->lines) {
            chomp;
            $r += $callback->($_);
        }
        return $r;
    }
    else {
        return $callback->($id_file);
    }
}

sub _list {
    my ($self, $query) = @_;

    my $sort  = $self->opts->{sort} // undef;
    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it;

    if (defined($query)) {
        $it = department->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        carp "sort not available without a query" if $sort;
        $it = department;
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
    my $HASH = $importer->first;

    print "deleting previous departments...\n";
    department->delete_all;

    _tree_parse_parser(
        $HASH->{tree},
        sub {
            my $rec = shift;
            department->add($rec, skip_commit => 1);
            print "added $rec->{_id}\n";
        }
    );
    department->commit;

    return 0;
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
    my $HASH = {};

    department->each(
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

    my $sort  = $self->opts->{sort} // undef;
    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it;

    if (defined($query)) {
        $it = department->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        $it = department;
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

    my $data = department->get($id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _add {
    my ($self, $file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret = 0;
    my $importer = Catmandu->importer('YAML', file => $file);

    department->add_many(
        $importer,
        on_validation_error => sub {
            my ($rec, $errors) = @_;
            say STDERR join("\n",
                $rec->{_id}, "ERROR: not a valid department", @$errors);
            $ret = 2;
        },
        on_success => sub {
            my ($rec) = @_;
            say "added $rec->{_id}";
        },
    );

    $ret;
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    if (department->delete($id)) {
        say "deleted $id";
        return 0;
    }
    else {
        say STDERR "ERROR: delete $id failed";
        return 2;
    }
}

sub _valid {
    my ($self, $file) = @_;

    croak "usage: $0 valid <FILE>" unless defined($file) && -r $file;

    my $validator = department->validator;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->each(
        sub {
            my $item = $_[0];

            unless ($validator->is_valid($item)) {
                my $errors = $validator->last_errors;
                my $id     = $item->{_id} // '';
                if ($errors) {
                    for my $err (@$errors) {
                        say STDERR "ERROR $id: $err";
                    }
                }
                else {
                    say STDERR "ERROR $id: not valid";
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

    librecat department list   [options] [<cql-query>]
    librecat department export [options] [<cql-query>]
    librecat department add    [options] <FILE>
    librecat department get    [options] <id> | <IDFILE>
    librecat department delete [options] <id> | <IDFILE>
    librecat department valid  [options] <FILE>
    librecay department tree   [options] [<FILE>]

    options:
        --sort=STR    (sorting results [only in combination with cql-query])
        --total=NUM   (total number of items to list/export)
        --start=NUM   (start list/export at this item)
=cut
