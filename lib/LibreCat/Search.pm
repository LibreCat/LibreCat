package LibreCat::Search;

use Catmandu::Sane;
use Catmandu::Util qw(trim);
use LibreCat::App::Helper;
use Try::Tiny;
use Moo;
use namespace::clean;

has bag => (is => 'ro', required => 1);

sub search {
    my ($self,$p, $bag) = @_;

    my $cql;
    if ($p->{q}) {
        push @{$p->{q}}, "status<>deleted";
        $cql = join(' AND ', @{$p->{q}});
    }
    else {
        $cql = "status<>deleted";
    }
    my $hits;
    try {
        my $bag = $self->bag;
        $hits = h->$bag->search(
            cql => $cql ||= '',
            sru_sortkeys => $self->sru_sort($p->{sort}),
            limit => $p->{limit} ||= h->config->{default_page_size},
            start => $p->{start} ||= 0,
            facets => $p->{facets} ||= {},
        );
    }
    catch {
        my $error;
        if ($_ =~ /(cql error\: unknown index .*?) at/) {
            $error = $1;
        }
        else {
            $error = "An error has occurred: $_";
        }
        $hits = {total => 0, error => $error};
    };

    return $hits;
}


sub default_facets {
    return {
        author      => {terms => {field => 'author.id',        size => 20,}},
        editor      => {terms => {field => 'editor.id',        size => 20,}},
        open_access => {terms => {field => 'file.open_access', size => 1}},
        popular_science => {terms => {field => 'popular_science', size => 1}},
        extern          => {terms => {field => 'extern',          size => 2}},
        status          => {terms => {field => 'status',          size => 8}},
        year            => {
            terms => {field => 'year', size => 100, order => 'reverse_term'}
        },
        type => {terms => {field => 'type', size => 25}},
        isi  => {terms => {field => 'isi',  size => 1}},
        pmid => {terms => {field => 'pmid', size => 1}},
    };
}

sub sru_sort {
    my ($self, $sort) = @_;

    my $cql_sort;
    $sort = h->string_array($sort);

    #foreach my $s (@$sort) {
    my $sru;
    @$sru = map {
        my $s = $_;
        my $r;
        if ($s =~ /(\w{1,})\.(asc|desc)/) {
            $r = "$1,," . ($2 eq "asc" ? "1" : "0");
        }
        elsif ($s =~ /\w{1,},,(0|1)/) {
            $r = $s;
        }
        #trim $r
        $r;
    } @$sort;

    join(@$sru, ' ');
    #$sru;
}

1;
