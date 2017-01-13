package LibreCat::Cmd::publication;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util;
use LibreCat::App::Helper;
use LibreCat::Validator::Publication;
use LibreCat::App::Catalogue::Controller::File;
use Path::Tiny;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat publication [options] list [<cql-query>]
librecat publication [options] export [<cql-query>]
librecat publication [options] get <id>
librecat publication [options] add <FILE>
librecat publication [options] delete <id>
librecat publication [options] purge <id>
librecat publication [options] valid <FILE>
librecat publication [options] files [<id>]|[<cql-query>]|[<FILE>]|REPORT
librecat publication [options] fetch <source> <id>
librecat publication [options] embargo ['update']

options:
    --total=NUM        (total number of items to list/export)
    --start=NUM        (start list/export at this item)
    --no-citation      (skip calculating citations when adding records)
    --version=NUM      (get a specific record version)
    --previous-version (get previous record version)
    --history          (get all record versions)

E.g.

# Search all publications with status 'private'
librecat publication list 'status exact private'

# Get the metadata for publication '2737383'
librecat publication get 2737383 > /tmp/data.yml

# Check if the YAML metadata is valid against the JSON scheme config/schema.yml
librecat publication valid /tmp/data.yml

# Update/add the metadata for a publication from a YAML file
librecat publication add /tmp/data.yml

# Find all files with an expired embargo date
librecat publication embargo

# Create a file update script to delete the embargo
librecat publication embargo update > /tmp/update.txt

# Update the file metadata
librecat publication files /tmp/update.txt

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (
        ['no-citation|nc', ""] ,
        ['total=i', ""] ,
        ['start=i',""] ,
    );
}

sub opts {
    state $opts = $_[1];
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands = qr/list|export|get|add|delete|purge|valid|files|fetch|embargo$/;

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
        return $self->_get(@$args);
    }
    elsif ($cmd eq 'add') {
        return $self->_add(@$args);
    }
    elsif ($cmd eq 'delete') {
        return $self->_delete(@$args);
    }
    elsif ($cmd eq 'purge') {
        return $self->_purge(@$args);
    }
    elsif ($cmd eq 'valid') {
        return $self->_valid(@$args);
    }
    elsif ($cmd eq 'files') {
        return $self->_files(@$args);
    }
    elsif ($cmd eq 'fetch') {
        return $self->_fetch(@$args);
    }
    elsif ($cmd eq 'embargo') {
        return $self->_embargo(@$args);
    }
}

sub _list {
    my ($self, $query) = @_;

    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it = LibreCat::App::Helper::Helpers->new->publication->searcher(
        cql_query => $query , total => $total , start => $start
    );

    my $count = $it->each(
        sub {
            my ($item) = @_;
            my $id = $item->{_id};
            my $title   = $item->{title}            // '---';
            my $creator = $item->{creator}->{login} // '---';
            my $status  = $item->{status};
            my $type    = $item->{type}             // '---';

            printf "%-2.2s %-40.40s %-10.10s %-60.60s %-10.10s %s\n", " " # not use
                , $id, $creator, $title, $status, $type;
        }
    );
    print "count: $count\n";

    return 0;
}

sub _export {
    my ($self, $query) = @_;

    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it = LibreCat::App::Helper::Helpers->new->publication->searcher(
        cql_query => $query , total => $total , start => $start
    );

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many($it);
    $exporter->commit;

    return 0;
}

sub _get {
    my ($self, $id, @opts) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $bag = Catmandu->store('backup')->bag('publication');
    my $rec;

    if (@opts && $opts[0] eq '--version') {
        my $version = $opts[1];
        $rec = $bag->get($id);
        if ($rec && $rec->{_version} && $rec->{_version} > $version) {
            $rec = $bag->get_version($id, $version);
        }
    } elsif (@opts && $opts[0] eq '--previous-version') {
        $rec = $bag->get_previous_version($id);
    } elsif (@opts && $opts[0] eq '--history') {
        $rec = $bag->get_history($id);
    } else {
        $rec = $bag->get($id);
    }

    Catmandu->export($rec, 'YAML') if $rec;

    return $rec ? 0 : 2;
}

sub _add {
    my ($self, $file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret       = 0;
    my $importer  = Catmandu->importer('YAML', file => $file);
    my $helper    = LibreCat::App::Helper::Helpers->new;
    my $validator = LibreCat::Validator::Publication->new;

    my $skip_citation = $self->opts->{'no-citation'} ? 1 : 0;

    my $records = $importer->benchmark->select(
        sub {
            my $rec = $_[0];

            if ($validator->is_valid($rec)) {
                $rec->{_id} //= $helper->new_record('publication');
                $helper->store_record('publication', $rec, $skip_citation);
                print "added $rec->{_id}\n";
                return 1;
            }
            else {
                print STDERR join("\n",
                    $rec->{_id},
                    "ERROR: not a valid publication",
                    @{$validator->last_errors}),
                    "\n";
                $ret = 2;
                return 0;
            }
        }
    );

    my $index = $helper->publication;
    $index->add_many($records);
    $index->commit;

    $ret;
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $result
        = LibreCat::App::Helper::Helpers->new->delete_record('publication',
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

sub _purge {
    my ($self, $id) = @_;

    croak "usage: $0 purge <id>" unless defined($id);

    my $result
        = LibreCat::App::Helper::Helpers->new->purge_record('publication',
        $id);

    if ($result) {
        print "purged $id\n";
        return 0;
    }
    else {
        print STDERR "ERROR: purge $id failed";
        return 2;
    }
}

sub _valid {
    my ($self, $file) = @_;

    croak "usage: $0 valid <FILE>" unless defined($file) && -r $file;

    my $validator = LibreCat::Validator::Publication->new;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->benchmark->each(
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
            }

            $ret = -1;
        }
    );

    return $ret == 0;
}

sub _fetch {
    my ($self, $source, $id) = @_;

    croak "need a source (axiv,crossref,epmc,...)" unless defined($source);
    croak "need an identifier" unless defined($id);

    my $pkg = Catmandu::Util::require_package($source, 'LibreCat::FetchRecord');

    unless ($pkg) {
        croak "failed to load LibreCat::FetchRecord::$source";
    }

    $id = path($id)->slurp_utf8 if -r $id;

    my @perl = $pkg->new->fetch($id);

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many(\@perl);
    $exporter->commit;

    return 0;
}

sub _embargo {
    my ($self, @args) = @_;

    my $update = $args[0] && $args[0] eq 'update';

    my $helper = LibreCat::App::Helper::Helpers->new;
    my $now    = $helper->now;
    $now =~ s/T.*//;

    my $query = "embargo < $now";
    my $it = $helper->publication->searcher(cql_query => $query);

    printf "%-9s\t%-9s\t%-12.12s\t%-14.14s\t%-15.15s\t%s\n",
        qw(id file_id access_level request_a_copy embargo file_name);

    my $printer = sub {
        my ($item) = @_;
        return unless $item->{file} && ref($item->{file}) eq 'ARRAY';

        my $process = 0;
        for my $file (@{$item->{file}}) {
            my $embargo = Catmandu::Util::trim($file->{embargo});

            if ($update && length($embargo) && $embargo le $now) {
                $process = 1;
            }
            else {
                $process = 0;
            }

            # Show __all__ file files and indicate which ones should
            # be switched to open_access.
            printf "%-9d\t%-9d\t%-12.12s\t%-14.14s\t%-15.15s\t%s\n",
                $item->{_id}, $file->{file_id},
                $process ? 'open_access' : $file->{access_level},
                $process ? 0             : $file->{request_a_copy},
                $process ? 'NA' : $embargo // 'NA',
                $file->{file_name};
        }
    };

    $it->each($printer);
}

sub _files {
    my ($self, $file) = @_;

    if ($file && $file eq 'REPORT') {
        $self->_files_reporter();
    }
    elsif ($file && $file =~ /^\d+$/) {
        $self->_files_list($file);
    }
    elsif ($file && -r $file) {
        $self->_files_load($file);
    }
    else {
        $self->_files_list($file);
    }

    return 0;
}

sub _files_list {
    my ($self, $id) = @_;
    printf "%-9s\t%-9s\t%-20.20s\t%-20.20s\t%-15.15s\t%s\n",
        qw(id file_id access_level relation embargo file_name);

    my $printer = sub {
        my ($item) = @_;
        return unless $item->{file} && ref($item->{file}) eq 'ARRAY';

        for my $file (@{$item->{file}}) {
            printf "%-9d\t%-9d\t%-20.20s\t%-20.20s\t%-15.15s\t%s\n",
                $item->{_id}, $file->{file_id}, $file->{access_level},
                $file->{relation}, $file->{embargo} // 'NA',
                $file->{file_name};
        }
    };

    if (defined($id) && $id =~ /^[0-9A-Za-z-]+$/) {
        my $data = LibreCat::App::Helper::Helpers->new->get_publication($id);
        $printer->($data);
    }
    elsif (defined($id)) {
        LibreCat::App::Helper::Helpers->new->publication->searcher(
            cql_query => $id)->each($printer);
    }
    else {
        LibreCat::App::Helper::Helpers->new->publication->each($printer);
    }
}

sub _files_load {
    my ($self, $filename) = @_;
    $filename = '/dev/stdin' if $filename eq '-';

    croak "list - can't open $filename for reading" unless -r $filename;
    local (*FH);

    my $helper = LibreCat::App::Helper::Helpers->new;
    my $importer = Catmandu->importer('TSV', file => $filename);

    my $prev_id = undef;
    my $files   = [];

    my @allowed_fields = qw(
        id
        access_level creator content_type
        date_created date_updated file_id
        file_name file_size open_access
        request_a_copy
        relation title description embargo
    );

    my $checked = 0;

    $importer->each(
        sub {
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
                my $data = $helper->get_publication($id);

                if ($data) {
                    $self->_file_process($data, $files)
                        && $helper->update_record('publication', $data);
                }
                else {
                    warn "$id - no such publication";
                }

                $files = [];
            }

            push @$files, $file;

            $prev_id = $id;
        }
    );

    if ($files) {
        my $data = $helper->get_publication($prev_id);

        if ($data) {
            $self->_file_process($data, $files)
                && $helper->update_record('publication', $data);
        }
        else {
            warn "$prev_id - no such publication";
        }
    }
}

sub _file_process {
    my ($self, $data, $files) = @_;

    return undef unless $data;

    my $id = $data->{_id};
    my %file_map = map {$_->{file_name} => $_} @{$data->{file}};

    # Update the files with stored data
    my $nr = 0;
    for my $file (@$files) {
        $nr++;

        my $name = $file->{file_name};
        my $old  = $file_map{$name};

        # Copy the old metadata if available
        if ($old) {
            for my $key (keys %$old) {
                if (!exists $file->{$key} || !length $file->{$key}) {
                    $file->{$key} = $old->{$key};
                }
            }
        }

        # Delete the keys that are set to 'NA'
        for my $key (keys %$file) {
            delete $file->{$key} if $file->{$key} eq 'NA';
        }

        unless ($file->{file_id}
            && $file->{date_created}
            && $file->{date_updated}
            && $file->{content_type}
            && $file->{creator})
        {
            $file
                = LibreCat::App::Catalogue::Controller::File::update_file($id,
                $file);
        }
    }

    $data->{file} = $files;

    1;
}

sub _files_reporter {
    my $file_store = Catmandu->config->{filestore}->{default}->{package};
    my $file_opt   = Catmandu->config->{filestore}->{default}->{options};

    my $pkg
        = Catmandu::Util::require_package($file_store, 'LibreCat::FileStore');
    my $files = $pkg->new(%$file_opt);

    my $exporter = Catmandu->exporter('TSV'
                            , header  => 1
                            , fields => [qw(status container filename error)]);

    LibreCat::App::Helper::Helpers->new->publication->each(sub {
        my ($item) = @_;
        return unless $item->{file} && ref($item->{file}) eq 'ARRAY';

        for my $file (@{$item->{file}}) {
            my $pub_id    = $item->{_id};
            my $file_name = $file->{file_name};

            my $status = 'OK';
            my $error  = '';

            if (my $container = $files->get($pub_id)) {
                if ($container->exists($file_name)) {
                    $status = 'OK'
                }
                else {
                    $status = 'ERROR';
                    $error = 'no such file';
                }
            }
            else {
                $status = 'ERROR';
                $error = 'no such container';
            }

            $exporter->add({
                status    => $status ,
                container => $pub_id ,
                filename  => $file_name ,
                error     => $error
            });
        }
    });

    $exporter->commit;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::publication - manage librecat publications

=head1 SYNOPSIS

    librecat publication list [<cql-query>]
    librecat publication export
	librecat publication get <id>
	librecat publication add <FILE>
	librecat publication delete <id>
    librecat publication purge <id>
    librecat publication valid <FILE>
    librecat publication files [<id>]|[<cql-query>]|[<FILE>]|REPORT
    librecat publication fetch <source> <id>
    librecat publication embargo ['update']

    options:
        --total=NUM   (total number of items to list/export)
        --start=NUM   (start list/export at this item)
        --no-citation (skip calculating citations when adding records)
=cut
