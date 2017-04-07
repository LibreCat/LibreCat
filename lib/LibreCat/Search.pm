package LibreCat::Search;

use Catmandu::Sane;
use Catmandu::Util qw(trim :is);
use Catmandu;
use Dancer qw(:syntax);
use Moo;
use Hash::Merge::Simple qw(merge);
use Try::Tiny;
use namespace::clean;

with 'Catmandu::Logger';

has store => (is => 'ro', required => 1,);

sub native_search {
    my ($self, $bag_name, $search_params) = @_;

    return undef unless $bag_name;

    $self->log->debug(
        "executing $bag_name->search: " . to_dumper($search_params));
    my $hits;

    try {
        $hits = $self->store->bag($bag_name)->search(%$search_params);
    }
    catch {
        $self->log->error($_);
        $self->log->error(
            "$bag_name->search failed: " . to_dumper($search_params));
        $hits = Catmandu::Hits->new(
            start => $search_params->{start},
            limit => $search_params->{limit},
            total => 0,
            hits  => [],
        );
    };

    $self->log->debug("found: " . $hits->total . " hits");

    # hack for now: refactor facets, then this can be removed
    foreach (qw(next_page last_page page previous_page pages_in_spread)) {
        $hits->{$_} = $hits->$_;
    }

    $hits;
}

sub search {
    my ($self, $bag_name, $p) = @_;

    return undef unless $bag_name;

    my %search_params = (
        cql_query    => $self->_cql_query($p),
        sru_sortkeys => $self->_sru_sort($p->{sort}) // '',
        limit        => $self->_set_limit($p->{limit}),
        start        => $p->{start} // 0,
        facets => merge($p->{facets}, Catmandu->config->{default_facets}),
    );

    $self->log->debug(
        "executing $bag_name->search: " . to_dumper(\%search_params));
    my $hits;

    try {
        $hits = $self->store->bag($bag_name)->search(%search_params);
    }
    catch {
        $self->log->error(
            "$bag_name->search failed: " . to_dumper(\%search_params));
        $hits = Catmandu::Hits->new(
            start => $search_params{start},
            limit => $search_params{limit},
            total => 0,
            hits  => [],
        );
    };

    $self->log->debug("found: " . $hits->total . " hits");

    # hack for now: refactor facets, then this can be removed
    foreach (qw(next_page last_page page previous_page pages_in_spread)) {
        $hits->{$_} = $hits->$_;
    }

    $hits;
}

sub _cql_query {
    my ($self, $p) = @_;

    my @cql;

    my $q = is_array_ref($p->{q}) ? $p->{q} : [$p->{q}];

    for my $part (@$q) {
        if (defined($part) && length($part)) {

            # auto-escape wildcards
            my $mode   = '=';
            my $search = '';

            if ($part =~ /^"(.*)"$/) {
                $mode   = 'exact';
                $search = $1;
            }
            else {
                $mode   = '=';
                $search = $part;
            }

            $search =~ s{(["\*\?])}{\\$1}g;
            push @cql, "basic $mode \"$search\"";
        }
    }

    $p->{cql} = $self->_string_array($p->{cql});
    push @cql, @{$p->{cql}};

    return join(' AND ', @cql) // '';
}

sub _set_limit {
    my ($self, $limit) = @_;

    if ($limit) {
        ($limit > Catmandu->config->{maximum_page_size})
            ? return Catmandu->config->{maximum_page_size}
            : return $limit;
    }
    else {
        return Catmandu->config->{default_page_size};
    }
}

sub _sru_sort {
    my ($self, $sort) = @_;

    return '' unless $sort;
    $sort = $self->_string_array($sort);

    return join(
        ' ',
        map {
            my $s = trim $_;
            unless ($self->_is_sru_sort($s)) {
                if ($s =~ /(\w{1,})\.(asc|desc)/) {
                    "$1,," . ($2 eq "asc" ? "1" : "0");
                }
            }
        } @$sort
    );
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
    }
    else {
        return undef;
    }
}

1;
