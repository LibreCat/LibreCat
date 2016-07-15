package LibreCat::Cmd::user;

use Catmandu::Sane;
use App::Helper;
use App::bmkpasswd qw(mkpasswd);
use LibreCat::Validator::Researcher;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat user [options] list
librecat user [options] add <FILE>
librecat user [options] get <id>
librecat user [options] delete <id>
librecat user [options] valid <FILE>

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
    elsif ($cmd eq 'publication') {
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
    my $count = App::Helper::Helpers->new->researcher->each(
        sub {
            my ($item)   = @_;
            my $id       = $item->{_id};
            my $login    = $item->{login};
            my $name     = $item->{full_name};
            my $status   = $item->{account_status};
            my $type     = $item->{account_type};
            my $is_admin = $item->{super_admin};

            printf "%-2.2s %5d %-20.20s %-40.40s %-10.10s %s\n",
                $is_admin ? "*" : " ", $id, $login, $name, $status, $type;
        }
    );
    print "count: $count\n";

    return 0;
}

sub _export {
    my $h = App::Helper::Helpers->new;

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many($h->researcher);
    $exporter->commit;

    return 0;
}

sub _get {
    my ($seld, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = App::Helper::Helpers->new->get_person($id);

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
    my $is_new = 0;

    my $helper = App::Helper::Helpers->new;

    unless (exists $data->{_id} && defined $data->{_id}) {
        $is_new = 1;
        $data->{_id} = $helper->new_record('researcher');
        $data->{password} = mkpasswd($data->{password}) if exists $data->{password};
    }

    my $validator = LibreCat::Validator::Researcher->new;

    if ($validator->is_valid($data)) {
        my $result = $helper->update_record('researcher', $data);

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
        print STDERR join("\n", @{$validator->last_errors}), "\n";
        return 2;
    }
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $h      = App::Helper::Helpers->new;
    my $result = $h->researcher->delete($id);

    if ($h->researcher->commit) {
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

    my $validator = LibreCat::Validator::Researcher->new;

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

LibreCat::Cmd::user - manage librecat users

=head1 SYNOPSIS

    librecat user list
    librecat user export
    librecat user add <FILE>
    librecat user get <id>
    librecat user delete <id>
    librecat user valud <FILE>

=cut
