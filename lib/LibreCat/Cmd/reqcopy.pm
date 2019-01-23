package LibreCat::Cmd::reqcopy;

use Catmandu::Sane;
use Catmandu;
use Date::Simple qw(date today);
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat reqcopy list
librecat reqcopy get <id>
librecat reqcopy expire
librecat reqcopy delete <id>

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/^(list|get|expire|delete)$/;

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
    elsif ($cmd eq 'get') {
        return $self->_get(@$args);
    }
    elsif ($cmd eq 'expire') {
        return $self->_expire(@$args);
    }
    elsif ($cmd eq 'delete') {
        return $self->_delete(@$args);
    }
}

sub _list {
    my ($self) = @_;

    my $it = Catmandu->store('main')->bag('reqcopy');

    my $count = $it->each(
        sub {
            my ($item)  = @_;
            my $id            = $item->{_id} // '';
            my $approved      = $item->{approved} ? 'Y' : 'N';
            my $date_expires  = $item->{date_expires};
            my $record        = $item->{record_id};
            my $file_name     = $item->{file_name};
            my $file_id       = $item->{file_id};
            my $user_email    = $item->{user_email};

            printf "%s %s %s %s %s\n", $id, $date_expires, $record, $file_name, $user_email;
        }
    );

    print "count: $count\n";

    return 0;
}

sub _get {
    my ($self, $pid) = @_;

    croak "usage: $0 get <id>" unless defined($pid);

    my $reqcopy = Catmandu->store('main')->bag('reqcopy');

    my $item = $reqcopy->get($pid);

    return 1 unless $item;

    my $id            = $item->{_id} // '';
    my $approved      = $item->{approved} ? 'Y' : 'N';
    my $date_expires  = $item->{date_expires};
    my $record        = $item->{record_id};
    my $file_name     = $item->{file_name};
    my $file_id       = $item->{file_id};
    my $user_email    = $item->{user_email};

    print <<EOF;
id           : $id
approved     : $approved
date_expires : $date_expires
record       : $record
file_name    : $file_name
file_id      : $file_id
user_email   : $user_email
EOF

    my $publication = Catmandu->store('main')->bag('publication');

    my $pub = $publication->get($record);

    return 0 unless $pub;

    my $title     = $pub->{title};
    my $files     = $pub->{file} // [];
    my $creator   = $pub->{creator}->{login};
    my $rac_email = '';

    for my $file (@$files) {
        if ($file->{file_id} eq $file_id) {
            $rac_email = $file->{rac_email};
        }
    }

    print <<EOF;
rac_email    : $rac_email
title        : $title
creator      : $creator
EOF

    return 0;
}

sub _expire {
    my $bag = Catmandu->store('main')->bag('reqcopy');

    my $count = 0;
    $bag->each(
        sub {
            my $rec  = $_[0];
            my $diff = today() - date($rec->{date_expires});

            if ($diff > 0) {
                print "Expiring " . $rec->{_id} . "\n";
                $bag->delete($rec->{_id});
            }
        }
    );

    $bag->commit;

    print "count expired: 0\n";

    return 0;
}

sub _delete {
    my ($self, $pid) = @_;

    croak "usage: $0 delete <id>" unless defined($pid);

    my $reqcopy = Catmandu->store('main')->bag('reqcopy');

    my $record = $reqcopy->get($pid);

    return 1 unless $record;

    $reqcopy->delete($pid);

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::reqcopy - update the request-a-copy db

=head1 SYNOPSIS

    librecat reqcopy list
    librecat reqcopy get <id>
    librecat reqcopy expire
    librecat reqcopy delete <id>

=cut
