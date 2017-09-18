package LibreCat::App::Catalogue::Route::importer;

=head1 NAME

LibreCat::App::Catalogue::Route::importer - central handler for import routes

=cut

use Catmandu::Sane;
use Catmandu::Util;
use Catmandu::Fix::trim as => 'trim';
use Dancer ':syntax';
use LibreCat::App::Helper;
use URL::Encode qw(url_decode);

sub _fetch_record {
    my ($id, $source) = @_;

    return undef unless ($source =~ /^[a-zA-Z0-9]+$/);

    # check agency: crossref or datacite
    if ($source eq 'crossref') {
        $id =~ s{^\D+[:\/]}{};

        my $data = Catmandu->importer(
            'getJSON',
            from    => url_decode("http://api.crossref.org/works/$id/agency"),
            timeout => 10,
        )->first;

        if (   $data->{message}
            && $data->{message}->{agency}->{id} eq "datacite")
        {
            $source = "datacite";
        }
    }

    my $pkg
        = Catmandu::Util::require_package($source, 'LibreCat::FetchRecord');

    unless ($pkg) {
        h->log->error("failed to load LibreCat::FetchRecord::$source");
        return undef;
    }

    h->log->debug("Processing LibreCat::FetchRecord::$source $id");

    $pkg->new->fetch($id);
}

=head2 POST /librecat/record/import

Returns a form with imported data.

=cut

post '/librecat/record/import' => sub {
    my $p = params;
    trim($p, 'id',     'whitespace');
    trim($p, 'source', 'whitespace');

    state $bag = LibreCat->store->bag('publication');
    my $user = h->get_person(session->{personNumber});
    my $id   = $p->{id};
    my $data
        = request->upload('data')
        ? request->upload('data')->content
        : $p->{data};
    my $source = $p->{source};

    try {
        my $imported_records = _fetch_record($p->{id} // $data, $source);

        die "no records imported" unless $imported_records;

        for my $pub (@$imported_records) {
            $pub->{_id}    = $bag->generate_id;
            $pub->{status} = 'new'
                ; # new is the status of records not checked by users/reviewers
            $pub->{creator}
                = {id => session->{personNumber}, login => session->{user}};
            $pub->{user_id}    = session->{personNumber};
            $pub->{department} = $user->{department};

            # Use config/hooks.yml to register functions
            # that should run before/after importing publications
            LibreCat->hook('publication-import')->fix_around(
                $pub,
                sub {
                    $bag->add($pub);
                }
            );
        }

        return template "backend/add_new",
            {
            ok => "Imported "
                . int(@$imported_records)
                . " record(s) from $source",
            imported => $imported_records
            };
    }
    catch {
        $id //= substr($data, 0, 40) . '...';
        h->log->error("import failed: $_");
        return template "backend/add_new",
            {error => "Could not import $id from source $p->{source}."};
    };

};

1;
