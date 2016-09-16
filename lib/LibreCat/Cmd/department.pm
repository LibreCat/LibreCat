package LibreCat::Cmd::department;

use Catmandu::Sane;
use LibreCat::App::Helper;
use LibreCat::Validator::Department;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat department [options] list
librecat department [options] export
librecat department [options] add <FILE>
librecat department [options] get <id>
librecat department [options] delete <id>
librecat department [options] valid <FILE>

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

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
        return $self->_export;
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
}

sub _list {
    my $count = LibreCat::App::Helper::Helpers->new->department->each(
        sub {
            my ($item)  = @_;
            my $id      = $item->{_id};
            my $name    = $item->{name};
            my $display = $item->{display};
            my $layer   = $item->{layer};

            printf "%-2.2d %9d %-40.40s %s\n", $layer, $id, $name, $display;
        }
    );
    print "count: $count\n";

    return 0;
}

sub _export {
    my $h = LibreCat::App::Helper::Helpers->new;

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many($h->department);
    $exporter->commit;

    return 0;
}

sub _get {
    my ($self, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = LibreCat::App::Helper::Helpers->new->get_department($id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _add {
    my ($self, $file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret = 0;
    my $importer = Catmandu->importer('YAML', file => $file);
    my $helper = LibreCat::App::Helper::Helpers->new;
    my $validator = LibreCat::Validator::Department->new;

    my $records = $importer->select(sub {
        my $rec = $_[0];

        $rec->{_id} //= $helper->new_record('department');

        if ($validator->is_valid($rec)) {
            $helper->store_record('department', $rec);
            print "added $rec->{_id}\n";
            return 1;
        }

        print STDERR join("\n", "ERROR: not a valid department", @{$validator->last_errors}), "\n";
        return 0;
    });

    my $index = $helper->department;
    $index->add_many($records);
    $index->commit;

    $ret;
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $h = LibreCat::App::Helper::Helpers->new;

    my $result = $h->department->delete($id);

    if ($h->department->commit) {
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

    my $validator = LibreCat::Validator::Department->new;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->each(
        sub {
            my $item = $_[0];

            unless ($validator->is_valid($item)) {
                my $errors = $validator->last_errors();
                my $id     = $item->{_id} // '';
                if ($errors) {
                    for my $err (@$errors) {
                        print STDERR "ERROR $id: $err\n";
                    }
                }
                else {
                    print STDERR "ERROR $id: not valid\n";
                }
            }

            $ret = -1;
        }
    );

    return $ret == 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::department - manage librecat departments

=head1 SYNOPSIS

    librecat department list
    librecat department export
    librecat department add <FILE>
    librecat department get <id>
    librecat department delete <id>
    librecat department valid <FILE>

=cut
