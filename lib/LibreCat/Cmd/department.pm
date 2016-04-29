package LibreCat::Cmd::department;

use Catmandu::Sane;
use App::Helper;
use LibreCat::Validator::Department;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
	return <<EOF;
Usage:

librecat department [options] list
librecat department [options] add <FILE>
librecat department [options] get <id>
librecat department [options] delete <id>

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (
    );
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/list|get|add|delete/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    binmode(STDOUT,":encoding(utf-8)");

    if ($cmd eq 'list') {
        return $self->_list(@$args);
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
}

sub _list {
    my $count = App::Helper::Helpers->new->department->each(sub {
        my ($item) = @_;
        my $id       = $item->{_id};
        my $name     = $item->{name};
        my $display  = $item->{display};
        my $layer    = $item->{layer};

        printf "%-2.2d %9d %-40.40s %s\n"
                    , $layer
                    , $id
                    , $name
                    , $display;
    });
    print "count: $count\n";

    return 0;
}

sub _get {
    my ($self,$id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = App::Helper::Helpers->new->get_department($id);

    Catmandu->export($data, 'YAML') if $data;

    return $data ? 0 : 2;
}

sub _add {
    my ($self,$file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->each( sub {
        my $item = $_[0];
        $ret += $self->_adder($item);
    });

    return $ret == 0;
}

sub _adder {
    my ($self,$data) = @_;

    my $validator = LibreCat::Validator::Department->new;

    if ($validator->is_valid($data)) {
        my $result = App::Helper::Helpers->new->update_record('department', $data);
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
        print STDERR "ERROR: not a valid department\n";
        print STDERR join("\n",@{$validator->last_errors}) , "\n";
        return 2;
    }
}

sub _delete {
    my ($self,$id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $h = App::Helper::Helpers->new;

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

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::department - manage librecat departments

=head1 SYNOPSIS

    librecat department list
    librecat department add <FILE>
    librecat department get <id>
    librecat department delete <id>

=cut
