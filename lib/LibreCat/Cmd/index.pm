package LibreCat::Cmd::index;

use Catmandu::Sane;
use LibreCat::JobQueue;
use LibreCat::Index;
use parent qw(LibreCat::Cmd);
use Carp;

sub description {
    return <<EOF;
Usage:

librecat index [--background] [--id=...] bag [bag]
librecat index status
librecat index initialize
librecat index switch

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (['background|bg', ""], ['id=s', ""], );
}

sub opts {
    state $opts = $_[1];
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands = qr/initialize|status|bag|switch/;

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    if ($cmd eq 'bag') {
        return $self->_bag(@$args);
    }
    elsif ($cmd eq 'status') {
        return $self->_status(@$args);
    }
    elsif ($cmd eq 'initialize') {
        print "Use this command during installation only.\nMake sure you have a fresh elasticsearch install (or run 'curl -XDELETE localhost:9200/*').\nAre you sure you want to run this initialize command [y/N]:";
        my $start = <STDIN>;
        chomp($start);
        if (lc $start eq 'y') {
            print "WE ARE RUNNING!\n";
            return $self->_initialize(@$args);
        }
        else {
            print "You have cancelled the initialize command.\n";
        }
    }
    elsif ($cmd eq 'switch') {
        return $self->_switch(@$args);
    }
}

sub _bag {
    my ($self,$bag) = @_;

    croak "need a bag" unless $bag;

    my $queue = LibreCat::JobQueue->new;

    if (my $id = $self->opts->{id}) {
        my $job_id
            = $queue->add_job('indexer', {bag => $bag, id => $id});
        return $job_id if $self->opts->{background};
        print "[$job_id]:";
        while (1) {
            print "+";
            my $job = $queue->job_status($job_id);
            last if $job->done;
            sleep 1;
        }
        print "DONE\n";
        return;
    }

    my $job_id = $queue->add_job('indexer', {bag => $bag});

    if ($self->opts->{background}) {
        say $job_id;
    }
    else {
        say "job $job_id";

        my $job;
        my $prev_n = 0;
        while (1) {
            $job = $queue->job_status($job_id);
            if ($job->queued) {
                say 'waiting for worker';
            }
            elsif ($job->running) {
                my ($n, $total) = $job->progress;
                if ($n > $prev_n) {
                    say "indexing $n/$total";
                    $prev_n = $n;
                }
            }
            else {
                say 'done';
                return;
            }
            sleep 1;
        }
    }

    1;
}

sub _status {
    my ($self) = @_;
    my $status = LibreCat::Index->get_status;
    Catmandu->exporter('YAML')->add($status);
}

sub _initialize {
    my ($self) = @_;

    LibreCat::Index->initialize;
}

sub _switch {
    my ($self) = @_;

    my $ind_name = Catmandu->config->{store}->{search}->{options}->{'index_name'};
    my $ind1 = $ind_name ."1";
    my $ind2 = $ind_name ."2";

    my $elastic_search = Search::Elasticsearch->new();

    my $i_status = LibreCat::Index->get_status;

    if ($i_status->{active_index}) {
        if ($i_status->{active_index} eq $ind1){
            for my $ind (@{$i_status->{all_indices}}){
                next if $ind eq $ind1;
                $self->_do_delete($ind, $elastic_search);
            }
            $self->_do_switch($ind1, $ind2, $elastic_search);
        }
        elsif ($i_status->{active_index} eq $ind2){
            for my $ind (@{$i_status->{all_indices}}){
                next if $ind eq $ind2;
                $self->_do_delete($ind, $elastic_search);
            }
            $self->_do_switch($ind2, $ind1, $elastic_search);
        }
        else {
            croak "Expecting $ind1 or $ind2 but found " . $i_status->{active_index} . " as active index";
        }
    }
    else {
        # There is no alias
        if($i_status->{all_indices} and $i_status->{number_of_indices}){
            # but there are one or more indices
            for  my $ind (@{$i_status->{all_indices}}){
                $self->_do_delete($ind, $elastic_search);
            }
        }
        $self->_do_switch("No index", $ind1, $elastic_search);
    }

    return 0;
}

sub _do_delete {
    my ($self, $old, $elastic_search) = @_;

    $elastic_search->indices->delete(index => $old);
    print "Deleted index $old\n";
}

sub _do_switch {
    my ($self, $old, $new, $elastic_search) = @_;

    my $main_store = Catmandu->store('main');
    my $ind_name   = Catmandu->config->{store}->{search}->{options}->{'index_name'};

    print "$old is active, new index will be $new.\n";

    my $store = Catmandu->store('search', index_name => $new);
    my @bags = qw(publication project award user department research_group);

    for my $b (@bags) {
        my $bag = $store->bag($b);
        $bag->add_many($main_store->bag($b));
        $bag->commit;
    }

    print "New index is $new. Testing...\n";
    my $checkForIndex = $elastic_search->indices->exists(index => $new);
    my $checkForAlias = $elastic_search->indices->exists(index => $ind_name);

    if ($checkForIndex) {
        print "Index $new exists. Setting index alias $ind_name to $new and testing again.\n";

        if (!$checkForAlias) {
            # First run, no alias present
            $elastic_search->indices->update_aliases(
                body => {
                    actions => [
                        { add => { alias => $ind_name, index => $new }},
                    ]
                }
            );
        }
        else {
            $elastic_search->indices->update_aliases(
                body => {
                    actions => [
                        { add    => { alias => $ind_name, index => $new }},
                        { remove => { alias => $ind_name, index => $old }}
                    ]
                }
            );
        }

        $checkForIndex = $elastic_search->indices->exists(index => $ind_name);

        if ($checkForIndex) {
            # First run, no old index to be deleted
            print "Alias $ind_name is ok and points to index $new.\nDone!\n";
        }
        else {
            print "Error: Could not create alias $ind_name.\n";
            exit;
        }
    }
    else {
        print "Error: Could not create index $new.\n";
        exit;
    }
}


1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::index - manage index jobs

=head1 SYNOPSIS

    librecat index [--background] [--id=...] bag [bag]
    librecat index status
    librecat index initialize
    librecat index switch

=cut
