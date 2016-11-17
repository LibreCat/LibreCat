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

    my $pub;
    my $user = h->get_person(session->{personNumber});
    my $edit_mode = params->{edit_mode} || $user->{edit_mode} || "";

    try {
        my $id     = $p->{id};
        my $data   = request->upload('data') ? request->upload('data')->content : $p->{data};
        my $source = $p->{source};

        # Use config/hooks.yml to register functions
        # that should run before/after adding new publications
        # E.g. create a hooks to change the default fields
        state $hook = h->hook('import-new-' . $source);

        $pub = _fetch_record( $p->{id} // $data, $source );

        $hook->fix_before($pub);

        unless ($pub) {
            my $id = $p->{id} // '<data>';
            h->log->error("import failed for $id in $source");
            return template "backend/add_new",
                    {error =>  "No record found with ID $id in $source."};
        }

        $pub->{_id} = h->new_record('publication');
        my $type = $pub->{type} || 'journal_article';
        my $templatepath = "backend/forms";
        $pub->{department} = $user->{department};

        if (   ($edit_mode and $edit_mode eq "expert")
            or (!$edit_mode and session->{role} eq "super_admin"))
        {
            $templatepath .= "/expert";
        }

        $pub->{new_record} = 1;

        $hook->fix_after($pub);

        return template "$templatepath/$type", $pub;
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
