package LibreCat::Cmd::publication;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util;
use Catmandu::Plugin::DynamicChecksum;
use LibreCat qw(queue publication timestamp);
use LibreCat::App::Catalogue::Controller::File;
use Path::Tiny;
use Carp;
use LibreCat::Audit;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat publication list    [options] [<cql-query>]
librecat publication export  [options] [<cql-query>]
librecat publication get     [options] <id> | <IDFILE>
librecat publication add     [options] <FILE> <OUTFILE>
librecat publication delete  [options] <id> | <IDFILE>
librecat publication purge   [options] <id> | <IDFILE>
librecat publication valid   [options] <FILE>
librecat publication files   [options] [<id>]|[<cql-query>]|[<FILE>]|REPORT
librecat publication fetch   [options] <source> <id>
librecat publication embargo [options] ['update']
librecat publication checksum [options] list|init|test|update <id> | <IDFILE>

E.g.

# Search all publications with status 'private'
librecat publication list 'status exact private'

# Sort all publications by tite (force a query using empty quotes)
librecat publication list --sort "title,,1" ""

# Get the metadata for publication '2737383'
librecat publication get 2737383 > /tmp/data.yml

# Check if the YAML metadata is valid against the JSON scheme config/schema.yml
librecat publication valid /tmp/data.yml

# Update/add the metadata for a publication from a YAML file
librecat publication add /tmp/data.yml

# Fetch a record from arxiv
librecat publication fetch arxiv abs/1401.5761 > /tmp/record.yml
librecat publication add /tmp/record.yml

# Find all files with an expired embargo date
librecat publication embargo

# Create a file update script to delete the embargo
librecat publication embargo update > /tmp/update.txt

# Export the files metadata
librecat publication files --csv [id|cql] > /tmp/update.txt

# Import the files metadata
librecat publication files --csv /tmp/update.txt

# Check if all the files in the publicatons are found in the file store
librecat publication files REPORT

# Test the checksums found in the metadata against the file_store for
# an ID or file with ID-s
librecat publication checksum test ID

# Calculate the checksum for files found in the metadata and store it in the
# metadata record
librecat publication checksum init ID

# Test and update the checksums for files found in the metadata record with
# the data found in the file_store
librecat publication checksum update ID

Options:
EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (
        ['total=i',   "total number of items to list/export"],
        ['start=i',   "start list/export at this item"],
        ['sort=s',    "sorting results [only in combination with cql-query]"],
        ['log=s',     "write an audit message"],
        ['version=i', "get a specific record version"],
        ['previous-version', "get previous record version"],
        ['history',          "get all record versions"],
        ['with-citations',   "process citations while adding records"],
        ['with-files',       "process files while addings records"],
        ['no-check-version', "add records without checking versions"],
        ['csv',              "import csv/tsv metadata in `files` command"],
    );
}

sub opts {
    if ($_[1]) {
        $_[0]->{__opts} = $_[1];
    }
    $_[0]->{__opts};
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands
        = qr/list|export|get|add|delete|purge|valid|files|fetch|embargo|checksum$/;

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

        return $self->id_or_file(
            $id,
            sub {
                $self->_get(shift);
            }
        );
    }
    elsif ($cmd eq 'add') {
        return $self->_add(@$args);
    }
    elsif ($cmd eq 'delete') {
        my $id = shift @$args;

        return $self->id_or_file(
            $id,
            sub {
                $self->_delete(shift);
            }
        );
    }
    elsif ($cmd eq 'purge') {
        my $id = shift @$args;

        return $self->id_or_file(
            $id,
            sub {
                $self->_purge(shift);
            }
        );
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
    elsif ($cmd eq 'checksum') {
        return $self->_checksum(@$args);
    }
}

sub audit {
    my $self = $_[0];
    $self->{_audit} //= LibreCat::Audit->new();
    $self->{_audit};
}

sub audit_message {
    my ($self, $id, $action, $message) = @_;
    $self->audit()->add(
        {
            id      => $id,
            bag     => 'publication',
            process => 'librecat publication',
            action  => $action,
            message => $message,
        }
    );
}

sub _list {
    my ($self, $query) = @_;

    my $sort  = $self->opts->{sort}  // undef;
    my $total = $self->opts->{total} // undef;
    my $start = $self->opts->{start} // undef;

    my $it;

    if (defined($query)) {
        $it = publication->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        carp "sort not available without a query" if $sort;
        $it = publication;
        $it = $it->slice($start // 0, $total)
            if (defined($start) || defined($total));
    }

    my $count = $it->each(
        sub {
            my ($item) = @_;
            my $id = $item->{_id};
            my $title   = $item->{title}            // '---';
            my $creator = $item->{creator}->{login} // '---';
            my $status  = $item->{status};
            my $type    = $item->{type}             // '---';

            printf "%-40.40s %-10.10s %-60.60s %-10.10s %s\n", $id, $creator,
                $title, $status, $type;
        }
    );

    print STDERR "count: $count\n";

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
        $it = publication->searcher(
            cql_query    => $query,
            total        => $total,
            start        => $start,
            sru_sortkeys => $sort
        );
    }
    else {
        $it = publication;
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
    my ($self, $id) = @_;

    croak "usage: $0 get <id>" unless defined($id);

    my $pubs = publication;

    my $rec;

    if (defined(my $version = $self->opts->{'version'})) {
        $rec = $pubs->get($id);
        if ($rec && $rec->{_version} && $rec->{_version} > $version) {
            $rec = $pubs->get_version($id, $version);
        }
    }
    elsif ($self->opts->{'previous-version'}) {
        $rec = $pubs->get_previous_version($id);
    }
    elsif ($self->opts->{'history'}) {
        $rec = $pubs->get_history($id);
    }
    else {
        $rec = $pubs->get($id);
    }

    if (my $msg = $self->opts->{log}) {
        $self->audit_message($id, 'get', $msg);
    }

    Catmandu->export($rec, 'YAML') if $rec;

    return $rec ? 0 : 2;
}

sub _add {
    my ($self, $file, $out_file) = @_;

    croak "usage: $0 add <FILE>" unless defined($file) && -r $file;

    my $ret      = 0;
    my $importer = Catmandu->importer('YAML', file => $file);
    my $exporter;

    if (defined $out_file) {
        $exporter = Catmandu->exporter('YAML', file => $out_file);
    }

    my $skip_before_add = [];
    push @$skip_before_add, "citation" unless $self->opts->{"with_citations"};
    push @$skip_before_add, "files"    unless $self->opts->{"with_files"};
    push @$skip_before_add, "check_version"
        if $self->opts->{"no_check_version"};

    publication->add_many(
        $importer,
        skip_before_add     => $skip_before_add,
        on_validation_error => sub {
            my ($rec, $errors) = @_;

            my @t_errors = map {$_->localize();} @$errors;

            $self->log->errorf("%s not a valid publication %s",
                $rec->{_id}, \@t_errors);
            say STDERR join("\n",
                $rec->{_id}, "ERROR: not a valid publication", @t_errors);
            $ret = 2;
        },
        on_success => sub {
            my ($rec) = @_;

            if ($exporter) {
                $exporter->add($rec);
            }
            else {
                say "added $rec->{_id}";
            }

            if (my $msg = $self->opts->{log}) {
                $self->audit_message($rec->{_id}, 'add', $msg);
            }
        },
    );

    if ($exporter) {
        $exporter->commit;
    }

    $ret;
}

sub _delete {
    my ($self, $id) = @_;

    croak "usage: $0 delete <id>" unless defined($id);

    my $result = publication->delete($id);

    if ($result) {

        if (my $msg = $self->opts->{log}) {
            $self->audit_message($id, 'delete', $msg);
        }

        print "deleted $id\n";
        return 0;
    }
    else {
        print STDERR "ERROR: delete $id failed\n";
        return 2;
    }
}

sub _purge {
    my ($self, $id) = @_;

    croak "usage: $0 purge <id>" unless defined($id);

    my $result = publication->purge($id);

    if ($result) {

        if (my $msg = $self->opts->{log}) {
            $self->audit_message($id, 'purge', $msg);
        }

        print "purged $id\n";
        return 0;
    }
    else {
        print STDERR "ERROR: purge $id failed\n";
        return 2;
    }
}

sub _valid {
    my ($self, $file) = @_;

    croak "usage: $0 valid <FILE>" unless defined($file) && -r $file;

    my $validator = publication->validator;

    my $ret = 0;

    Catmandu->importer('YAML', file => $file)->benchmark->each(
        sub {
            my $item = $_[0];

            unless ($validator->is_valid($item)) {
                my $errors = $validator->last_errors();
                my $id     = $item->{_id} // '';
                if ($errors) {
                    for my $err (@$errors) {
                        say STDERR "ERROR $id: " . $err->localize();
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

sub _fetch {
    my ($self, $source, $id) = @_;

    croak "need a source (axiv,crossref,epmc,...)" unless defined($source);
    croak "need an identifier"                     unless defined($id);

    my $pkg
        = Catmandu::Util::require_package($source, 'LibreCat::FetchRecord');

    unless ($pkg) {
        croak "failed to load LibreCat::FetchRecord::$source";
    }

    $id = path($id)->slurp_utf8 if -r $id;

    my @records = $pkg->new->fetch($id);

    return 0 unless @records;

    my $exporter = Catmandu->exporter('YAML');
    $exporter->add_many(@records);
    $exporter->commit;

    return 0;
}

sub _embargo {
    my ($self, @args) = @_;

    my $update = $args[0] && $args[0] eq 'update';

    my $now = timestamp;
    $now =~ s/T.*//;

    my $query = "embargo < $now";
    my $it    = publication->searcher(cql_query => $query);

    my $exporter = Catmandu->exporter('YAML');

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

            my $embargo_to = $file->{embargo_to} // 'open_access';

            # Show __all__ files and indicate which ones should
            # be switched to open_access.
            $exporter->add(
                {
                    id           => $item->{_id},
                    file_id      => $file->{file_id},
                    access_level => $process
                    ? $embargo_to
                    : $file->{access_level},
                    embargo    => $process ? 'NA' : $embargo    // 'NA',
                    embargo_to => $process ? 'NA' : $embargo_to // 'NA',
                    file_name  => $file->{file_name},
                }
            );
        }
    };

    $it->each($printer);
    $exporter->commit;
}

sub _checksum {
    my ($self, $action, $id) = @_;

    croak "usage: $0 checksum initialize|test|update <id>"
        unless defined($action) && $action =~ /^(list|init|test|update)$/;
    croak "usage: $0 checksum $action <id>" unless defined($id);

    return $self->id_or_file(
        $id,
        sub {
            $self->_checksum_id($action, shift);
        }
    );
}

sub _checksum_id {
    my ($self, $action, $id) = @_;

    my $file_store = Catmandu->config->{filestore}->{default}->{package};
    my $file_opt   = Catmandu->config->{filestore}->{default}->{options};

    my $pkg = Catmandu::Util::require_package($file_store,
        'Catmandu::Store::File');

    my $pubs = publication;

    my $rec = $pubs->get($id);

    unless ($rec) {
        print STDERR "ERROR: checksum $id failed\n";
        return 2;
    }

    my $files = $pkg->new(%$file_opt)->index->files($id);

    my $pub_files = $rec->{file} // [];

    my $update = 0;
    my $errors = 0;

    for my $fi (@$pub_files) {
        my ($msg, $stored_checksum);
        my $file_name     = $fi->{file_name};
        my $file_checksum = $fi->{checksum} // '';
        my $si            = $files->get($file_name);

        if (!$si) {
            $msg = 'NOT_FOUND';
            $errors++;
        }
        elsif ($action eq 'list') {
            $msg = '';
        }
        elsif ($action eq 'init') {
            if (Catmandu::Util::is_string($file_checksum)) {
                $msg = 'OK';
            }
            else {
                $file_checksum = $fi->{checksum}
                    = Catmandu::Plugin::DynamicChecksum::dynamic_checksum(
                    $files, $si);
                $update++;
                $msg = 'OK';
            }
        }
        elsif ($action eq 'test') {
            if (Catmandu::Util::is_string($file_checksum)) {
                my $stored_checksum
                    = Catmandu::Plugin::DynamicChecksum::dynamic_checksum(
                    $files, $si);
                if ($file_checksum eq $stored_checksum) {
                    $msg = 'OK';
                }
                else {
                    $msg = 'INVALID';
                    $errors++;
                }
            }
            else {
                $msg = 'IGNORED';
            }
        }
        elsif ($action eq 'update') {
            $file_checksum = $fi->{checksum}
                = Catmandu::Plugin::DynamicChecksum::dynamic_checksum($files,
                $si);
            $update++;
            $msg = 'OK';
        }
        else {
            croak "$0 : unknown action $action";
        }

        printf "%s %-9s %-32s %s\n", $id, $msg, $file_checksum, $file_name;
    }

    if ($update) {
        $pubs->add(
            $rec,
            on_validation_error => sub {
                my ($rec, $e) = @_;

                my @t_errors = map {$_->localize();} @$e;

                $self->log->errorf("%s not a valid publication %s",
                    $rec->{_id}, \@t_errors);
                say STDERR join("\n",
                    $rec->{_id}, "ERROR: not a valid publication", @t_errors);
                $errors++;
            }
        );

        if (my $msg = $self->opts->{log}) {
            $self->audit_message($rec->{_id}, 'add', $msg);
        }
    }

    return $errors = 0 ? 0 : 2;
}

sub _files {
    my ($self, $file) = @_;

    if ($file && $file eq 'REPORT') {
        $self->_files_reporter();
    }
    elsif ($file && $file =~ /^\d+$/) {
        $self->_files_list($file);
    }
    elsif ($file && $file eq '-') {
        $self->_files_load($file);
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

    my $fields
        = [qw(id file_id access_level relation embargo embargo_to file_name)];

    my $exporter = Catmandu->exporter($self->opts->{csv} ? 'TSV' : 'YAML',
        fields => $fields);

    my $printer = sub {
        my ($item) = @_;
        return unless $item->{file} && ref($item->{file}) eq 'ARRAY';

        for my $file (@{$item->{file}}) {
            $exporter->add(
                {
                    id           => $item->{_id},
                    file_id      => $file->{file_id},
                    access_level => $file->{access_level},
                    relation     => $file->{relation},
                    embargo      => $file->{embargo} // 'NA',
                    embargo_to   => $file->{embargo_to} // 'NA',
                    file_name    => $file->{file_name},
                    data         => $file->{data},
                }
            );
        }
    };

    if (defined($id) && $id =~ /^[0-9A-Za-z-]+$/) {
        my $data = publication->get($id);
        $printer->($data);
    }
    elsif (defined($id)) {
        publication->searcher(cql_query => $id)->each($printer);
    }
    else {
        publication->each($printer);
    }
    $exporter->commit;
}

sub _files_load {
    my ($self, $filename) = @_;
    $filename = '/dev/stdin' if $filename eq '-';

    croak "list - can't open $filename for reading" unless -r $filename;
    local (*FH);

    my $importer = Catmandu->importer($self->opts->{csv} ? 'TSV' : 'YAML',
        file => $filename);

    my $update_file = sub {
        my ($id, $files) = @_;
        if (my $data = publication->get($id)) {
            $self->_file_process($data, $files) && publication->add($data,
                    on_validation_error => sub {
                        my ($rec, $errors) = @_;

                        my @t_errors = map {$_->localize();} @$errors;

                        $self->log->errorf("%s not a valid publication %s",
                            $rec->{_id}, \@t_errors);
                        say STDERR join("\n",
                            "ERROR: " . $rec->{_id} . " not a valid publication", @t_errors);
                    }
            );
        }
        else {
            warn "$id - no such publication";
        }

        if (my $msg = $self->opts->{log}) {
            $self->audit_message($id, 'files', $msg);
        }
    };

    my %allowed_fields = map {($_ => 1)} qw(
        id
        access_level creator content_type
        date_created date_updated file_id
        file_name file_size checksum
        relation title description embargo embargo_to
        data
    );

    my $current_id;
    my $files = [];

    $importer->each(
        sub {
            my $file = $_[0];

            for my $key (keys %$file) {
                my $new_key = Catmandu::Util::trim $key;
                croak "file - field '$key' not allowed in file"
                    unless $allowed_fields{$new_key};
                $file->{$new_key} = Catmandu::Util::trim delete $file->{$key};
            }

            my $id = delete $file->{id};
            croak "file - no id column found" unless defined $id;
            $current_id //= $id;

            if ($id eq $current_id) {
                push @$files, $file;
                return;
            }
            else {
                $update_file->($current_id, $files);
            }

            $current_id = $id;
            $files      = [$file];
        }
    );

    if (defined $current_id) {
        $update_file->($current_id, $files);
    }
}

sub _file_process {
    my ($self, $data, $files) = @_;

    return undef unless $data;
    return $data unless $files;

    my $id       = $data->{_id};
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

        # If we have have a new file do all metadata processing...
        unless ($old) {
            $file
                = LibreCat::App::Catalogue::Controller::File::update_file($id,
                $file);
        }

        unless (defined $file) {
            croak
                "FATAL - failed to update `$name' for $id (does it exist in the file store?)";
        }
    }

    # Check if we are deleting files...
    if ($data->{file}) {
        my $lookup = {};

        for my $file (@$files) {
            my $file_name = $file->{file_name};
            my $file_id   = $file->{file_id};
            $lookup->{"$file_id--$file_name"} = 1;
        }

        for my $file (@{$data->{file}}) {
            my $file_name = $file->{file_name};
            my $file_id   = $file->{file_id};
            croak "FATAL - cowardly refusing to delete `$file_name` from $id"
                unless $lookup->{"$file_id--$file_name"};
        }
    }

    $data->{file} = $files;

    for my $file (@$files) {
        my $file_name = $file->{file_name};
        print "updated $id `$file_name`\n";
    }

    1;
}

sub _files_reporter {
    my ($self) = @_;

    my $file_store = Catmandu->config->{filestore}->{default}->{package};
    my $file_opt   = Catmandu->config->{filestore}->{default}->{options};

    my $pkg = Catmandu::Util::require_package($file_store,
        'Catmandu::Store::File');
    my $files = $pkg->new(%$file_opt);

    my $fields = [qw(container status filename error)];

    my $exporter = Catmandu->exporter($self->opts->{csv} ? 'TSV' : 'YAML',
        fields => $fields);

    publication->each(
        sub {
            my ($item) = @_;
            return unless $item->{file} && ref($item->{file}) eq 'ARRAY';

            for my $file (@{$item->{file}}) {
                my $pub_id    = $item->{_id};
                my $file_name = $file->{file_name};

                my $status = 'OK';
                my $error  = '';

                if ($files->index->exists($pub_id)) {
                    if ($files->index->files($pub_id)->exists($file_name)) {
                        $status = 'OK';
                    }
                    else {
                        $status = 'ERROR';
                        $error  = 'no such file';
                    }
                }
                else {
                    $status = 'ERROR';
                    $error  = 'no such container';
                }

                $exporter->add(
                    {
                        status    => $status,
                        container => $pub_id,
                        filename  => $file_name,
                        error     => $error
                    }
                );
            }
        }
    );

    $exporter->commit;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::publication - manage librecat publications

=head1 SYNOPSIS

    librecat publication list    [options] [<cql-query>]
    librecat publication export  [options] [<cql-query>]
    librecat publication get     [options] <id> | <IDFILE>
    librecat publication add     [options] <FILE> <OUTFILE>
    librecat publication delete  [options] <id> | <IDFILE>
    librecat publication purge   [options] <id> | <IDFILE>
    librecat publication valid   [options] <FILE>
    librecat publication files   [options] [<id>]|[<cql-query>]|[<FILE>]|REPORT
    librecat publication fetch   [options] <source> <id>
    librecat publication embargo [options] ['update']
    librecat publication checksum [options] list|init|test|update <id> | <IDFILE>

    options:
        --sort=STR         (sorting results [only in combination with cql-query])
        --total=NUM        (total number of items to list/export)
        --start=NUM        (start list/export at this item)
        --version=NUM      (get a specific record version)
        --previous-version (get previous record version)
        --history          (get all record versions)
        --log=STR          (write an audit message)
        --with-citations   (process citations while adding records)
        --with-files       (process files while addings records)
        --no-check-version (add records without checking versions)
        --csv              (import csv/tsv metadata in `files` command)

=cut
