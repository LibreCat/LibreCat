package LibreCat::Search;

use Catmandu::Sane;
use Catmandu::Util qw(trim :is);
use Dancer qw(:syntax);
use LibreCat -self;
use Moo;
use Try::Tiny;
use namespace::clean;

with 'LibreCat::Logger';

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
            start => $search_params->{start} // 0,
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

    my $bag = $self->store->bag($bag_name);

    my @filters = map {
        $bag->translate_cql_query($_);
    } @{ $p->{cql} // [] };

    my $sub_query = {
        match_all => {}
    };

    my $query_string = is_array_ref( $p->{q} ) ?
        $p->{q}->[0] : is_string( $p->{q} ) ?
            $p->{q} : undef;

    #TODO: make this configurable
    if( is_string( $query_string ) ){

        $sub_query = {
            simple_query_string => {
                query => $query_string,
                lenient => "true",
                analyze_wildcard => "false",
                default_operator => "OR",
                minimum_should_match => "100%",
                flags => "PHRASE|WHITESPACE",
                fields => ["all"]
            }
        };

    }

    my $query = {
        bool => {
            filter => \@filters,
            must => $sub_query
        }
    };

    my %search_params = (
        query => $query,
        sru_sortkeys => $self->_sru_sort($p->{sort}) // '',
        limit        => $self->_set_limit($p->{limit}),
        start        => $p->{start} // 0,
        aggs         => $p->{facets} // {},
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
            start => $search_params{start} // 0,
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

__END__

=pod

=head1 NAME

LibreCat::Search - module that provides search functionality in LibreCat

=head1 SYNOPSIS

    use LibreCat::Search;

    my $s = LibreCat::Search->new(store => Catmandu->store('search'));
    $s->native_search();

    $s->search();

    # or through LibreCat
    use LibeCat -self;

    my $hits = librecat->searcher->search(...);


=head1 METHODS

=over

=item native_search($opts)

    $opts = {
        query => "title:dna",
        sort => '...', #optional
        start => 0, #optional
        limit => 20, #optional
    };

=item search($opts)

    $opts = {
        q => ["title=test", "year=2019"],
        sort => "year.desc", #optional
        start => 0, #optional
        limit => 20, #optional
    };

=back

=head1 SEE ALSO

L<LibreCat>

=cut
