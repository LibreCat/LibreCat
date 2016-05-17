package LibreCat::Cmd::award;

use Catmandu::Sane;
use App::Helper;
use LibreCat::Validator::Award;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
	return <<EOF;
Usage:

librecat award [options] list
librecat award [options] add <FILE>
librecat award [options] get <id>
librecat award [options] delete <id>

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
    my $h = App::Helper::Helpers->new;
    my $count = $h->award->each(sub {
        my ($item) = @_;
        my $id       = $item->{_id};
        my $title    = $item->{title};
        my $type     = $item->{rec_type};

        printf "%-2.2s %5.5s %-40.40s %s\n"
                    , " " # not used
                    , $id
                    , $title
                    , $type;
    });
    print "count: $count\n";

    return 0;
}

sub _get {
    my ($self,$id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $h = App::Helper::Helpers->new;
    my $data = $h->get_award($id);

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

    my $h = App::Helper::Helpers->new;
    my $validator = LibreCat::Validator::Award->new;

    if ($validator->is_valid($data)) {
        my $result = $h->update_record('award', $data);
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
        print STDERR "ERROR: not a valid award\n";
        print STDERR join("\n",@{$validator->last_errors}) , "\n";
        return 2;
    }
}

sub _delete {
    my ($self,$id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $h = App::Helper::Helpers->new;
    my $result = $h->award->delete($id);

    if ($h->award->commit) {
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

LibreCat::Cmd::award - manage librecat users

=head1 SYNOPSIS

    librecat award list
    librecat award add <FILE>
    librecat award get <id>
    librecat award delete <id>

=cut
