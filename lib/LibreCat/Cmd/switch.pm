package LibreCat::Cmd::switch;

use Catmandu::Sane;
use Catmandu;
use AnyEvent;
use AnyEvent::HTTP;
use Carp;
use parent qw(LibreCat::Cmd);
use Search::Elasticsearch;
use LibreCat::Index;

sub description {
    return <<EOF;
Usage:

librecat switch [-v|--verbose] index

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (['verbose|v', ""],);
}

sub opts {
    state $opts = $_[1];
}

sub command {
    my ($self, $opts, $args) = @_;

    $self->opts($opts);

    my $commands = qr/(index)/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    binmode(STDOUT, ":encoding(utf-8)");

    if ($cmd eq 'index') {
        return $self->_switch($opts, $args);
    }
}

sub _switch {
    my ($self, $opts, $args) = @_;

    my $ind_name = Catmandu->config->{store}->{search}->{options}->{'index_name'};
    my $ind1 = $ind_name ."1";
    my $ind2 = $ind_name ."2";

    my $e = Search::Elasticsearch->new();

    my $i_status = LibreCat::Index->get_status;

    if (!$i_status->{active_index}){
        # There is no alias
        if($i_status->{all_indices} and $i_status->{number_of_indices}){
            # but there are one or more indices
            foreach my $ind (@{$i_status->{all_indices}}){
                $self->_do_delete($ind, $e, $opts);
            }
        }
        $self->_do_switch("No index", $ind1, $e, $opts);
    }
    elsif ($i_status->{active_index}) {
        if($i_status->{active_index} eq $ind1){
            foreach my $ind (@{$i_status->{all_indices}}){
                next if $ind eq $ind1;
                $self->_do_delete($ind, $e, $opts);
            }
            $self->_do_switch($ind1, $ind2, $e, $opts);
        }
        elsif ($i_status->{active_index} eq $ind2){
            foreach my $ind (@{$i_status->{all_indices}}){
                next if $ind eq $ind2;
                $self->_do_delete($ind, $e, $opts);
            }
            $self->_do_switch($ind2, $ind1, $e, $opts);
        }
    }

    return 0;
}

sub _do_delete {
    my ($self, $old, $e, $opts) = @_;

    $e->indices->delete(index => $old);
    print "Deleted index $old\n" if $opts->{verbose};
}

sub _do_switch {
    my ($self, $old, $new, $e, $opts) = @_;

    my $backup_store = Catmandu->store('backup');
    my $ind_name = Catmandu->config->{store}->{search}->{options}->{'index_name'};

    print "$old is active, new index will be $new.\n" if $opts->{verbose};

    my $store = Catmandu->store('search', index_name => $new);
    my @bags = qw(publication project award researcher department research_group);

    foreach my $b (@bags) {
        my $bag = $store->bag($b);
        $bag->add_many($backup_store->bag($b));
        $bag->commit;
    }

    print "New index is $new. Testing...\n" if $opts->{verbose};
    my $checkForIndex = $e->indices->exists(index => $new);
    my $checkForAlias = $e->indices->exists(index => $ind_name);

    if($checkForIndex){
        print "Index $new exists. Setting index alias $ind_name to $new and testing again.\n" if $opts->{verbose};

        if(!$checkForAlias){
            # First run, no alias present
            $e->indices->update_aliases(
                body => {
                    actions => [
                        { add => { alias => $ind_name, index => $new }},
                    ]
                }
            );
        }
        else {
            $e->indices->update_aliases(
                body => {
                    actions => [
                        { add    => { alias => $ind_name, index => $new }},
                        { remove => { alias => $ind_name, index => $old }}
                    ]
                }
            );
        }

        $checkForIndex = $e->indices->exists(index => $ind_name);

        if($checkForIndex){
            # First run, no old index to be deleted
            print "Alias $ind_name is ok and points to index $new.\nDone!\n" if $opts->{verbose};
        }
        else {
            print "Error: Could not create alias $ind_name.\n" if $opts->{verbose};
            exit;
        }
    }
    else {
        print "Error: Could not create index $new.\n" if $opts->{verbose};
        exit;
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::url - check urls

=head1 SYNOPSIS

    librecat schemas url check <FILE> <OUTFILE>

=head1 commands

=head2 check

check all provided URLs

=cut
