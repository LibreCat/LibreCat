package LibreCat::Cmd::research_group;

use Catmandu::Sane;
use LibreCat qw(research_group);
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat research_group list   [options] [<cql-query>]
librecat research_group export [options] [<cql-query>]
librecat research_group add    [options] <FILE>
librecat research_group get    [options] <id> | <IDFILE>
librecat research_group delete [options] <id> | <IDFILE>
librecat research_group valid  [options] <FILE>

E.g.

librecat research_group list 'id = 1234'
librecat research_group --sort "name,,1" list ""  # force to use an empty query

Options:
EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (
        ['total=i', "total number of items to list/export"],
        ['start=i', "start list/export at this item"],
        ['sort=s',  "sorting results [only in combination with cql-query]"],
    );
}

sub opts {
    state $opts = $_[1];
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands = qr/list|export|get|add|delete|valid/;

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

        return $self->id_or_file(
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

        return $self->id_or_file(
            $id,
            sub {
                $self->_delete(shift);
            }
        );
    }
    elsif ($cmd eq 'valid') {
        return $self->_valid(@$args);
    }
}

sub _list {
    my ($self, $query) = @_;

    my $sort  = $self->opts->{sort} // undef;
    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it;

    if (defined($query)) {
        $it = research_group->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        carp "sort not available without a query" if $sort;
        $it = research_group;
        $it = $it->slice($start // 0, $total)
            if (defined($start) || defined($total));
    }

    my $count = $it->each(
        sub {
            my ($item)  = @_;
            my $id      = $item->{_id};
            my $name    = $item->{name};
            my $acronym = $item->{acronym} // '---';

            printf "%-40.40s %s %s\n", $id, $acronym, $name;
        }
    );
    print "count: $count\n";

    if (!defined($query) && defined($sort)) {
        print STDERR
            "warning: sort only active in combination with a query\n";
    }

    return 0;
}

sub _export {
    my ($self, $query) = @_;

    my $sort  = $self->opts->{sort} // undef;
    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it;

    if (defined($query)) {
        $it = research_group->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        $it = research_group;
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

    my $data = research_group->get($id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _add {
    my ($self, $file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret = 0;
    my $importer = Catmandu->importer('YAML', file => $file);

    research_group->add_many(
        $importer,
        on_validation_error => sub {
            my ($rec, $errors) = @_;
            say STDERR join("\n",
                $rec->{_id}, "ERROR: not a valid research_group",map {
                    $_->localize();
                } @$errors);
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

    if (research_group->delete($id)) {
        print "deleted $id\n";
        return 0;
    }
    else {
        print STDERR "ERROR: delete $id failed";
        return 2;
    }
}

sub _valid {
    my ($self, $file) = @_;

    croak "usage: $0 valid <FILE>" unless defined($file) && -r $file;

    my $validator = research_group->validator;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->each(
        sub {
            my $item = $_[0];

            unless ($validator->is_valid($item)) {
                my $errors = $validator->last_errors;
                my $id     = $item->{_id} // '';
                if ($errors) {
                    for my $err (@$errors) {
                        say STDERR "ERROR $id: " . $err->localize();
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

LibreCat::Cmd::research_group - manage librecat research_group-s

=head1 SYNOPSIS

    librecat research_group list   [options] [<cql-query>]
    librecat research_group export [options] [<cql-query>]
    librecat research_group add    [options] <FILE>
    librecat research_group get    [options] <id> | <IDFILE>
    librecat research_group delete [options] <id> | <IDFILE>
    librecat research_group valid  [options] <FILE>

    options:
        --sort=STR    (sorting results [only in combination with cql-query])
        --total=NUM   (total number of items to list/export)
        --start=NUM   (start list/export at this item)
=cut
