package LibreCat::Cmd::research_group;

use Catmandu::Sane;
use LibreCat::App::Helper;
use LibreCat::Validator::Research_group;
use Path::Tiny;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat research_group [options] list [<cql-query>]
librecat research_group [options] export [<cql-query>]
librecat research_group [options] add <FILE>
librecat research_group [options] get <id> | <IDFILE>
librecat research_group [options] delete <id> | <IDFILE>
librecat research_group [options] valid <FILE>

options:
    --sort=STR    (sorting results [only in combination with cql-query])
    --total=NUM   (total number of items to list/export)
    --start=NUM   (start list/export at this item)

E.g.

librecat research_group list 'id = 1234'
librecat research_group --sort "name,,1" list ""  # force to use an empty query

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

        return $self->_on_all($id, sub {
             $self->_get(shift);
        });
    }
    elsif ($cmd eq 'add') {
        return $self->_add(@$args);
    }
    elsif ($cmd eq 'delete') {
        my $id = shift @$args;

        return $self->_on_all($id, sub {
             $self->_delete(shift);
        });
    }
    elsif ($cmd eq 'valid') {
        return $self->_valid(@$args);
    }
}

sub _on_all {
    my ($self,$id_file,$callback) = @_;

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

    my $sort  = $self->opts->{sort}  // undef;
    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it;

    my $helper = LibreCat::App::Helper::Helpers->new;

    if (defined($query)) {
        $it = $helper->research_group->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        carp "sort not available without a query" if $sort;
        $it = $helper->main_research_group;
        $it = $it->slice($start // 0, $total)
            if (defined($start) || defined($total));
    }

    my $count = $it->each(
        sub {
            my ($item)  = @_;
            my $id      = $item->{_id};
            my $name    = $item->{name};
            my $acronym = $item->{acronym} // '---';

            printf "%-40.40s %5.5s %-40.40s %s\n", " "    # not used
                , $id, $acronym, $name;
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

    my $sort  = $self->opts->{sort}  // undef;
    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it;

    my $helper = LibreCat::App::Helper::Helpers->new;

    if (defined($query)) {
        $it = $helper->research_group->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        $it = $helper->main_research_group;
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

    my $helper = LibreCat::App::Helper::Helpers->new;

    my $data = $helper->main_research_group->get($id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _add {
    my ($self, $file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret      = 0;
    my $importer = Catmandu->importer('YAML', file => $file);
    my $helper   = LibreCat::App::Helper::Helpers->new;

    my $records = $importer->select(
        sub {
            my $rec = $_[0];

            $rec->{_id} //= $helper->new_record('research_group');

            my $is_ok = 1;

            $helper->store_record(
                'research_group',
                $rec,
                validation_error => sub {
                    my $validator = shift;
                    print STDERR join("\n",
                        $rec->{_id},
                        "ERROR: not a valid research_group",
                        @{$validator->last_errors}),
                        "\n";
                    $ret   = 2;
                    $is_ok = 0;
                }
            );

            return 0 unless $is_ok;

            print "added $rec->{_id}\n";

            return 1;
        }
    );

    my $index = $helper->research_group;
    $index->add_many($records);
    $index->commit;

    $ret;
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $result
        = LibreCat::App::Helper::Helpers->new->purge_record('research_group',
        $id);

    if ($result) {
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

    my $validator = LibreCat::Validator::Research_group->new;

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

LibreCat::Cmd::research_group - manage librecat research_group-s

=head1 SYNOPSIS

    librecat research_group list [<cql-query>]
    librecat research_group export [<cql-query>]
    librecat research_group add <FILE>
    librecat research_group get <id> | <IDFILE>
    librecat research_group delete <id> | <IDFILE>
    librecat research_group valid <FILE>

    options:
        --sort=STR    (sorting results [only in combination with cql-query])
        --total=NUM   (total number of items to list/export)
        --start=NUM   (start list/export at this item)
=cut
