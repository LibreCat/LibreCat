package LibreCat::Cmd::publication;

use Catmandu::Sane;
use Catmandu;
use App::Helper;
use LibreCat::Validator::Publication;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
	return <<EOF;
Usage:

librecat publication [options] list
librecat publication [options] get <id>
librecat publication [options] add <FILE>
librecat publication [options] delete <id>

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

    if ($cmd eq 'list') {
    	return $self->_list;
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
	my ($self) = @_;
    my $count = App::Helper::Helpers->new->publication->each(sub {
        my ($item) = @_;
        my $id       = $item->{_id};
        my $title    = $item->{title} // '---';
        my $creator  = $item->{creator}->{login} // '---';
        my $status   = $item->{status};
        my $type     = $item->{type} // '---';

        printf "%-2.2s %9d %-10.10s %-60.60s %-10.10s %s\n"
                    , " " # not use
                    , $id
                    , $creator
                    , $title
                    , $status
                    , $type;
    });
    print "count: $count\n";

    return 0;
}

sub _get {
    my ($self,$id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = App::Helper::Helpers->new->get_publication($id);

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

    my $validator = LibreCat::Validator::Publication->new;

    if ($validator->is_valid($data)) {
         my $result = App::Helper::Helpers->new->update_record('publication', $data);
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
         print STDERR "ERROR: not a valid researcher\n";
         print STDERR join("\n",@{$validator->last_errors}) , "\n";
         return 2;
    }
}

sub _delete {
    my ($self,$id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $result = App::Helper::Helpers->new->delete_record('publication',$id);

    if ($result) {
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

LibreCat::Cmd::publication - manage librecat publications

=head1 SYNOPSIS

    librecat publication list
	librecat publication get <id>
	librecat publication add <FILE>
	librecat publication delete <id>

=cut
