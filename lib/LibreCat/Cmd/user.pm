package LibreCat::Cmd::user;

use Catmandu::Sane;
use LibreCat::App::Helper;
use LibreCat::Validator::User;
use App::bmkpasswd qw(passwdcmp mkpasswd);
use Path::Tiny;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat user [options] list [<cql-query>]
librecat user [options] export [<cql-query>]
librecat user [options] add <FILE>
librecat user [options] get <id> | <IDFILE>
librecat user [options] delete <id> | <IDFILE>
librecat user [options] valid <FILE>
librecat user [options] passwd <id>

options:
    --sort=STR    (sorting results [only in combination with cql-query])
    --total=NUM   (total number of items to list/export)
    --start=NUM   (start list/export at this item)

E.g.

librecat user list 'id = 1234'
librecat user --sort "lastname,,1" list ""  # force to use an empty query

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (['total=i', ""], ['start=i', ""], ['sort=s', ""]);
}

sub opts {
    state $opts = $_[1];
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands = qr/list|export|get|add|delete|valid|passwd/;

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
    elsif ($cmd eq 'passwd') {
        return $self->_passwd(@$args);
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

    my $helper = LibreCat::App::Helper::Helpers->new;

    my $it;
    if (defined($query)) {
        $it = LibreCat::App::Helper::Helpers->new->user->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        carp "sort not available without a query" if $sort;
        $it = $helper->main_user;
        $it = $it->slice($start // 0, $total)
            if (defined($start) || defined($total));
    }

    my $count = $it->each(
        sub {
            my ($item) = @_;
            my $id = $item->{_id};
            my $login    = $item->{login}          // '---';
            my $name     = $item->{full_name}      // '---';
            my $status   = $item->{account_status} // '---';
            my $is_admin = $item->{super_admin}    // 0;

            printf "%-2.2s %-40.40s %-20.20s %-40.40s %-10.10s\n",
                $is_admin ? "*" : " ", $id, $login, $name, $status;
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

    if (defined($query)) {
        $it = LibreCat::App::Helper::Helpers->new->user->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        $it = Catmandu->store('main')->bag('user');
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
    my ($seld, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = Catmandu->store('main')->bag('user')->get($id);

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

            $rec->{_id} //= $helper->new_record('user');
            $rec->{password} = mkpasswd($rec->{password})
                if exists $rec->{password};

            my $is_ok = 1;

            $helper->store_record(
                'user',
                $rec,
                validation_error => sub {
                    my $validator = shift;
                    print STDERR join("\n",
                        $rec->{_id},
                        "ERROR: not a valid user",
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

    my $index = $helper->user;
    $index->add_many($records);
    $index->commit;

    $ret;
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $result
        = LibreCat::App::Helper::Helpers->new->purge_record('user',
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

    my $validator = LibreCat::Validator::User->new;

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

sub _passwd {
    my ($seld, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = LibreCat::App::Helper::Helpers->new->get_person($id);

    my $name = $data->{full_name};

    print "Password: ";
    system('/bin/stty', '-echo');
    my $password1 = <STDIN>;
    chop($password1);
    system('/bin/stty', 'echo');

    print "\nRepeat password: ";
    system('/bin/stty', '-echo');
    my $password2 = <STDIN>;
    chop($password2);
    system('/bin/stty', 'echo');
    print "\n";

    unless ($password1 eq $password2) {
        print STDERR "Passwords don't match\n";
        return 2;
    }

    $data->{password} = mkpasswd($password2);

    my $helper = LibreCat::App::Helper::Helpers->new;
    $helper->store_record('user', $data);

    my $index = $helper->user;
    $index->add($data);
    $index->commit;

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::user - manage librecat users

=head1 SYNOPSIS

    librecat user list [<cql-query>]
    librecat user export [<cql-query>]
    librecat user add <FILE>
    librecat user get <id> | <IDFILE>
    librecat user delete <id> | <IDFILE>
    librecat user valid <FILE>
    librecat user passwd <id>

    options:
        --sort=STR    (sorting results [only in combination with cql-query])
        --total=NUM   (total number of items to list/export)
        --start=NUM   (start list/export at this item)

=cut
