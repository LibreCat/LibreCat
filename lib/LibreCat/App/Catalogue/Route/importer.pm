package LibreCat::App::Catalogue::Route::importer;

=head1 NAME

LibreCat::App::Catalogue::Route::importer - central handler for import routes

=cut

use Catmandu::Sane;
use Catmandu::Util;
use Catmandu::Fix::trim as => 'trim';
use Dancer ':syntax';
use Dancer::Plugin::Auth::Tiny;
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

        if ( $data->{message} && $data->{message}->{agency}->{id} eq "datacite" ) {
            $source = "datacite";
        }
    }

    my $pkg = Catmandu::Util::require_package($source, 'LibreCat::FetchRecord');

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
post '/librecat/record/import' => needs login => sub {
    my $p = params;
    trim($p, 'id', 'whitespace');
    trim($p, 'source', 'whitespace');

    my $user       = h->get_person(session->{personNumber});

    try {
        my $id     = $p->{id};
        my $data   = request->upload('data') ? request->upload('data')->content : $p->{data};
        my $source = $p->{source};

        my @imported_records = _fetch_record( $p->{id} // $data, $source );

        for my $pub (@imported_records) {
            $pub->{_id}        = h->new_record('publication');
            $pub->{status}     = 'private';
            $pub->{creator}    = {
                    id => session->{personNumber},
                    login => session->{user}
            };
            $pub->{user_id}    = session->{personNumber};
            $pub->{department} = $user->{department};

            # Use config/hooks.yml to register functions
            # that should run before/after uploading QAE publications

            h->hook('import-new-')->fix_around(
                $pub,
                sub {
                    h->update_record('publication', $pub);
                }
            );
        }

        redirect '/librecat';
    }
    catch {
        my $id = $p->{id} // '<data>';
        h->log->error("import failed: $_");
        return template "backend/add_new",
            {error =>
                "Could not import ID $id from source $p->{source}."};
    };

};

1;
