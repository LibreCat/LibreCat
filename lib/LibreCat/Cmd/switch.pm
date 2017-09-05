package LibreCat::Cmd::switch;

use Catmandu::Sane;
use Catmandu;
use AnyEvent;
use AnyEvent::HTTP;
use Carp;
use parent qw(LibreCat::Cmd);
use Search::Elasticsearch;

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

    my $ind1_exists = $e->indices->exists(index => $ind1);
    my $ind2_exists = $e->indices->exists(index => $ind2);

    if (($ind1_exists and !$ind2_exists) or (!$ind1_exists and !$ind2_exists)) {
        $self->_do_switch($ind1, $ind2, $e);
    } elsif ($ind2_exists and !$ind1_exists) {
        $self->_do_switch($ind2, $ind1, $e);
    } else { # $pub1_exists and $pub2_exists
        print "Both indexes exist. Find out which one is running \n
        (curl -s -XGET 'http://localhost:9200/[alias]/_status') and delete \n
        the other (curl -s -XDELETE 'http://localhost:9200/[unused_index]').\n Then restart!\n";
        exit;
    }

    return 0;
}

sub _do_switch {
	my ($self, $old, $new, $e) = @_;

    my $backup_store = Catmandu->store('backup');
    my $ind_name = Catmandu->config->{store}->{search}->{options}->{'index_name'};

	print "Index $new does not exist yet, new index will be $new.\n" if ($self->opts->{v} or $self->opts->{verbose});

	my $store = Catmandu->store('search', index_name => $new);
	my @bags = qw(publication project award researcher department research_group);
	foreach my $b (@bags) {
		my $bag = $store->bag($b);
		$bag->add_many($backup_store->bag($b));
		$bag->commit;
	}

	print "New index is $new. Testing...\n";
	my $checkForIndex = $e->indices->exists(index => $new);
	my $checkForAlias = $e->indices->exists(index => $ind_name);

	if($checkForIndex){
		print "Index $new exists. Setting index alias $ind_name to $new and testing again.\n";

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

		if($checkForIndex and !$checkForAlias){
			# First run, no old index to be deleted
			print "Alias $ind_name is ok and points to index $new.\n Done!\n";
		}
		elsif($checkForIndex and $checkForAlias) {
			print "Alias $ind_name is ok and points to index $new. Deleting $old.\n";
			$e->indices->delete(index => $old);
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

LibreCat::Cmd::url - check urls

=head1 SYNOPSIS

    librecat schemas url check <FILE> <OUTFILE>

=head1 commands

=head2 check

check all provided URLs

=cut
