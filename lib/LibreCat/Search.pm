package LibreCat::Search;

use Catmandu::Sane;
use Catmandu::Util qw(trim :is);
use Catmandu;
use Moo;
use Hash::Merge::Simple qw(merge);
use namespace::clean;

has store => (
    is => 'ro',
    required => 1,
    # TODO: check if this is a Catmandu::Store
);

sub quick_search {
    my ($self, $bag_name, $p) = @_;

    return undef unless $bag_name;

    $self->store->bag($bag_name)->search(
        query => $p->{q} // '',
    );
}

sub search {
    my ($self, $bag_name, $p) = @_;

    return undef unless $bag_name;
    my $cql;

    $p->{q} = $self->_string_array($p->{q});
    $cql = join(' AND ', @{$p->{q}}) if $p->{q};
    my $store = $self->store;
    my $bag = $store->bag($bag_name);

    my $hits = $bag->search(
        cql_query => $cql // '',
        sru_sortkeys => $self->_sru_sort($p->{sort}) // '',
        limit => $p->{limit} // Catmandu->config->{default_page_size},
        start => $p->{start} // 0,
        facets => merge($p->{facets}, $self->_default_facets),
    );

    foreach (qw(next_page last_page page previous_page pages_in_spread)) {
        $hits->{$_} = $hits->$_;
    }

    $hits;
}


sub _default_facets {
    state $facets = Catmandu->config->{default_facets};
}

sub _sru_sort {
    my ($self, $sort) = @_;

    return '' unless $sort;
    $sort = $self->_string_array($sort);

    return join (' ', map {
        my $s = trim $_;
        unless ( $self->_is_sru_sort($s) ) {
            if ($s =~ /(\w{1,})\.(asc|desc)/) {
                "$1,," . ($2 eq "asc" ? "1" : "0");
            }
        }
    } @$sort );
}

sub _string_array {
    my ($self, $val) = @_;
    return [grep {is_string $_ } @$val] if is_array_ref $val;
    return [$val] if is_string $val;
    [];
}

sub _is_sru_sort {
    my ($self, $s) = @_;
    if ($s && $s =~ /\w{1,},,(0|1)/) {
        return $s;
    } else {
        return undef;
    }
}

1;
