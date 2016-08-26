package LibreCat::Cmd::publication;

use Catmandu::Sane;
use Catmandu;
use App::Helper;
use LibreCat::Validator::Publication;
use App::Catalogue::Controller::File;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat publication [options] list
librecat publication [options] export
librecat publication [options] get <id>
librecat publication [options] add <FILE>
librecat publication [options] delete <id>
librecat publication [options] valid <FILE>
librecat publication [options] files [ID]|[<FILE>]

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/list|export|get|add|delete|valid|files/;

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
    elsif ($cmd eq 'files') {
        return $self->_files(@$args);
    }
}

sub _list {
    my ($self) = @_;
    my $count = App::Helper::Helpers->new->publication->each(
        sub {
            my ($item) = @_;
            my $id = $item->{_id};
            my $title   = $item->{title}            // '---';
            my $creator = $item->{creator}->{login} // '---';
            my $status  = $item->{status};
            my $type    = $item->{type}             // '---';

            printf "%-2.2s %9d %-10.10s %-60.60s %-10.10s %s\n", " " # not use
                , $id, $creator, $title, $status, $type;
        }
    );
    print "count: $count\n";

    return 0;
}

sub _export {
    my $h = App::Helper::Helpers->new;

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many($h->publication);
    $exporter->commit;

    return 0;
}

sub _get {
    my ($self, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $data = App::Helper::Helpers->new->get_publication($id);

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
        $data->{_id} = $helper->new_record('publication');
    }

    my $validator = LibreCat::Validator::Publication->new;

    if ($validator->is_valid($data)) {
        my $result = $helper->update_record('publication', $data);

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
        print STDERR "ERROR: not a valid publication\n";
        print STDERR join("\n", @{$validator->last_errors}), "\n";
        return 2;
    }
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $result = App::Helper::Helpers->new->delete_record('publication', $id);

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

    my $validator = LibreCat::Validator::Publication->new;

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

sub _files {
    my ($self,$file) = @_;

    if ($file && $file =~ /^\d+$/) {
        $self->_files_list($file);
    }
    elsif ($file && -r $file) {
        $self->_files_load($file);
    }
    else {
        $self->_files_list;
    }

    return 0;
}

sub _files_list {
    my ($self,$id) = @_;
    printf "%-9s\t%-20.20s\t%-20.20s\t%-15.15s\t%s\n"
        , qw(id access_level relation embargo file_name);

    my $printer = sub {
            my ($item) = @_;
            return unless $item->{file} && ref($item->{file}) eq 'ARRAY';

            for my $file (@{$item->{file}}) {
                printf "%-9d\t%-20.20s\t%-20.20s\t%-15.15s\t%s\n"
                            , $item->{_id}
                            , $file->{access_level}
                            , $file->{relation}
                            , $file->{embargo} // 'NA'
                            , $file->{file_name};
            }
    };

    if ($id) {
        my $data = App::Helper::Helpers->new->get_publication($id);
        $printer->($data);
    }
    else {
        App::Helper::Helpers->new->publication->each($printer);
    }
}

sub _files_load {
    my ($self,$filename) = @_;
    $filename = '/dev/stdin' if $filename eq '-';

    croak "list - can't open $filename for reading" unless -r $filename;
    local(*FH);

    my $importer = Catmandu->importer('TSV', file => $filename);

    my $prev_id = undef;
    my $files  = [];

    my @allowed_fields = qw(
        id
        access_level creator content_type
        date_created date_updated file_id
        file_name file_size open_access
        relation title description embargo
    );

    my $checked = 0;

    $importer->each(sub {
        my $record = $_[0];

        my $file = {};

        for my $key (keys %$record) {
            my $new_key = $key;
            $new_key =~ s{^\s*|\s*$}{}g;
            $file->{$new_key} = $record->{$key};
            $file->{$new_key} =~ s{^\s*|\s*$}{}g;
            croak "file - field '$new_key' not allowed in file"
                    unless $checked || grep {/^$new_key$/} @allowed_fields;
        }

        $checked = 1;

        my $id = $file->{id};

        croak "file - no id column found?" unless defined($id);

        delete $file->{id};

        if ($prev_id && $prev_id ne $id) {
            $self->_file_process($prev_id,$files);
            $files = [];
        }

        push @$files , $file;

        $prev_id = $id;
    });

    $self->_file_process($prev_id,$files) if $files;
}

sub _file_process {
    my ($self,$id,$files) = @_;

    my $data = App::Helper::Helpers->new->get_publication($id);

    unless ($data) {
        warn "$id - no such publication";
        return;
    }

    my %file_map = map  { $_->{file_name} => $_ } @{$data->{file}};

    # Update the files with stored data
    my $nr = 0;
    for my $file (@$files) {
        $nr++;

        my $name = $file->{file_name};
        my $old  = $file_map{$name};

        # Copy the old metadata if available
        if ($old) {
            for my $key (keys %$old) {
                if (! exists $file->{$key} || ! length $file->{$key}) {
                    $file->{$key} = $old->{$key};
                }
            }
        }

        # Delete the keys that are set to 'NA'
        for my $key (keys %$file) {
            delete $file->{$key} if $file->{$key} eq 'NA';
        }

        unless (
            $file->{file_id} && $file->{date_created} && $file->{date_updated} &&
            $file->{content_type} && $file->{creator}
        ) {
            $file = App::Catalogue::Controller::File::update_file($id,$file);
        }
    }

    $data->{file} = $files;

    $self->_adder($data);
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::publication - manage librecat publications

=head1 SYNOPSIS

    librecat publication list
    librecat publication export
	librecat publication get <id>
	librecat publication add <FILE>
	librecat publication delete <id>
    librecat publication valid <FILE>
    librecat publication files [ID]|[<FILE>]

=cut
