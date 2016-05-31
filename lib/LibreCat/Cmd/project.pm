package LibreCat::Cmd::project;

use Catmandu::Sane;
use App::Helper;
use LibreCat::Validator::Project;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat project [options] list
librecat project [options] export
librecat project [options] add <FILE>
librecat project [options] get <id>
librecat project [options] delete <id>
librecat project [options] valid <FILE>

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
    my $count = App::Helper::Helpers->new->project->each(
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
    my $h = App::Helper::Helpers->new;

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many($h->project);
    $exporter->commit;

    return 0;
}

sub _get {
    my ($self, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = App::Helper::Helpers->new->get_project($id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _add {
    my ($self, $file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->each(
        sub {
            my $item = $_[0];
            $ret += $self->_adder($item);
        }
    );

    return $ret == 0;
}

sub _adder {
    my ($self, $data) = @_;

    my $validator = LibreCat::Validator::Project->new;

    if ($validator->is_valid($data)) {
        my $result
            = App::Helper::Helpers->new->update_record('project', $data);
        if ($result) {
            print "added " . $data->{_id} . "\n";
            return 0;
        }
        else {
            print "ERROR: add " . $data->{_id} . " failed\n";
            return 2;
        }
    }
    else {
        print STDERR "ERROR: not a valid project\n";
        print STDERR join("\n", @{$validator->last_errors}), "\n";
        return 2;
    }
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $h = App::Helper::Helpers->new;

    my $result = $h->project->delete($id);

    if ($h->project->commit) {
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

    my $validator = LibreCat::Validator::Project->new;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->each(
        sub {
            my $item = $_[0];

            unless ($validator->is_valid($item)) {
                my $errors = $validator->last_errors();
                my $id     = $item->{_id};
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

LibreCat::Cmd::project - manage librecat projects

=head1 SYNOPSIS

    librecat project list
    librecat project export
    librecat project add <FILE>
    librecat project get <id>
    librecat project delete <id>
    librecat project valid <FILE>

=cut
