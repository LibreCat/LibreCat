package LibreCat::Cmd::index;

use Catmandu::Sane;
use LibreCat::JobQueue;
use LibreCat::Index;
use parent qw(LibreCat::Cmd);
use Carp;

sub description {
    return <<EOF;
Usage:
librecat index initialize
librecat index create BAG
librecat index drop BAG
librecat index status
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

    my $commands = qr/initialize|status|create|drop|switch/;

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    if ($cmd eq 'create') {
        return $self->_create(@$args);
    }
    elsif ($cmd eq 'drop') {
        return $self->_drop(@$args);
    }
    elsif ($cmd eq 'status') {
        return $self->_status(@$args);
    }
    elsif ($cmd eq 'initialize') {
        print "Use this command during installation only.\nThis command will delete existing indices!\nAre you sure you want to run it [y/N]:";
        my $start = <STDIN>;
        chomp($start);
        if (lc $start eq 'y') {
            return $self->_initialize(@$args);
        }
        else {
            print STDERR "Command initialize has been cancelled\n";
        }
    }
    elsif ($cmd eq 'switch') {
        return $self->_switch(@$args);
    }
}

sub _create {
    my ($self,$name) = @_;

    croak "need a bag" unless $name;

    my $main_store = Catmandu->store('main');
    my $store      = Catmandu->store('search');

    my $bag = $store->bag($name);
    $bag->add_many($main_store->bag($name)->benchmark);
    $bag->commit;
}

sub _drop {
    my ($self,$name) = @_;

    croak "need a bag" unless $name;

    my $store = Catmandu->store('search');
    my $bag   = $store->bag($name);
    $bag->delete_all;
    $bag->commit;
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

    my $elastic_search = Search::Elasticsearch->new();

    my $i_status = LibreCat::Index->get_status;

    if (my $active = $i_status->{active_index}) {
        print "Active index: $active\n";

        if ($active =~ /([12])$/) {
            my $inactive = $active;
            $inactive =~ tr/12/21/;
            for my $ind (@{$i_status->{all_indices}}){
                next if $ind eq $active;
                print "Deleting: $ind\n";
                $self->_do_delete($ind, $elastic_search);
            }
            print "Switching: $active -> $inactive\n";
            $self->_do_switch($active, $inactive, $elastic_search);
        }
        else {
            croak "Expecting $active\[12\] but found " . $i_status->{active_index} . " as active index";
        }
    }
    else {
        print "No active index found\n";
        if($i_status->{all_indices} and $i_status->{number_of_indices}){
            for my $ind (@{$i_status->{all_indices}}){
                print "Deleting: $ind\n";
                $self->_do_delete($ind, $elastic_search);
            }
        }
        print "Switching: No index -> $ind_name\1\n";
        $self->_do_switch("No index", $ind_name . 1, $elastic_search);
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
    my $ind_name   = Catmandu->config->{store}->{search}->{options}->{index_name};

    print "$old is active, new index will be $new.\n";

    my $store = Catmandu->store('search', index_name => $new);

    my @bags = keys %{Catmandu->config->{store}->{search}->{options}->{bags}};

    for my $b (@bags) {
        print "Indexing $b...\n";
        my $bag = $store->bag($b);
        $bag->add_many($main_store->bag($b)->benchmark);
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

    librecat index initialize
    librecat index create BAG
    librecat index drop BAG
    librecat index status
    librecat index switch

=cut
