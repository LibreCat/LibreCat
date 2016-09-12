package LibreCat::App::Search::Route::mark;

=head1 NAME

LibreCat::App::Search::Route::mark - handles mark and ordering of marked records.
This is stored in the session.

=cut

use Catmandu::Sane;
use Catmandu qw(store export_to_string);
use Catmandu::Util qw(:is :array);
use Dancer qw(:syntax);
use Catmandu::Util;
use List::Util;
use DateTime;
use LibreCat::App::Helper;

=head2 GET /marked

Returns list of marked records.

=cut

get '/marked' => sub {

    my $p        = h->extract_params();
    my $fmt      = $p->{fmt};
    my $explinks = $p->{explinks};
    my $marked   = session 'marked';
    my ($hits, @tmp_hits, @result_hits);

    if ($marked and ref $marked eq "ARRAY") {
        while (my @chunks = splice(@$marked, 0, 100)) {
            $p->{q}     = ["(id=" . join(' OR id=', @chunks) . ")"];
            $p->{limit} = 100;
            $hits       = h->search_publication($p);
            push @tmp_hits, @{$hits->{hits}};
        }
        $hits->{explinks} = $explinks;
        $hits->{style} = params->{style} || h->config->{default_style};

        # sort hits according to id-order in session (making drag and drop sorting possible)
        foreach my $sh (@{session 'marked'}){
            my @hit = grep {$sh eq $_->{_id}} @tmp_hits;
            push @result_hits, @hit;
        }
    }

    $hits->{hits} = \@result_hits;
    $hits->{total} = scalar @tmp_hits;

    if ($fmt and $fmt ne 'html' and $hits->{total} ne "0") {
        h->export_publication($hits, $fmt);
    }
    else {
        template 'marked/marked.tt', $hits;
    }

};

=head2 POST /mark/:id

Mark the record with ID :id.

=cut

post '/mark/:id' => sub {

    my $id  = param 'id';
    my $del = params->{'x-tunneled-method'};
    if ($del) {
        my $marked = session 'marked';
        if ($marked) {
            $marked = [grep {$_ ne $id} @$marked];
            session 'marked' => $marked;
        }
        content_type 'application/json';
        return to_json {ok => true, total => scalar @$marked,};
    }

    forward '/marked', {q => "id=$id"};

};

post '/marked' => sub {

    my $p      = h->extract_params();
    my $del    = params->{'x-tunneled-method'};
    my $marked = [];
    $marked     = session 'marked';
    $p->{limit} = h->config->{maximum_page_size};
    $p->{start} = 0;
    push @{$p->{q}}, "status exact public";

    if ($del) {
        if (session 'marked') {
            session 'marked' => [];
        }
        return to_json {ok => true, total => 0,};
    }

    my $hits = h->search_publication($p);

    if ($hits->{total} > $hits->{limit} && @$marked == 500) {
        return to_json {
            ok => true,
            message =>
                "the marked list has a limit of 500 records, only the first 500 records will be added",
            total => scalar @$marked,
        };
    }
    elsif ($hits->{total}) {
        foreach (@{$hits->{hits}}) {
            my $id = $_->{_id};
            push @$marked, $id unless array_includes($marked, $id);
        }

        session 'marked' => $marked;
    }

    content_type 'application/json';
    return to_json {ok => true, total => scalar @$marked,};

};

get '/marked_total' => sub {
    my $marked = [];
    $marked = session 'marked' if session 'marked';
    content_type 'application/json';
    return to_json {ok => true, total => scalar @$marked,};
};

post '/reorder/:id/:newpos' => sub {

    forward '/reorder', {id => params->{id}, newpos => params->{newpos}};

};

post '/reorder' => sub {

    my $marked = session 'marked';

    $marked = [grep {$_ ne params->{id}} @$marked];

    my @rest = splice(@$marked, params->{newpos});
    push @$marked, params->{id};
    push @$marked, @rest;

    session 'marked' => $marked;

};

1;
