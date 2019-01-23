package LibreCat::App::Catalogue::Route::importer;

=head1 NAME

LibreCat::App::Catalogue::Route::importer - central handler for import routes

=cut

use Catmandu::Sane;
use Catmandu::Util;
use Catmandu::Importer::getJSON;
use LibreCat qw(publication);
use Catmandu::Fix::trim as => 'trim';
use Dancer ':syntax';
use LibreCat::App::Helper;
use URL::Encode qw(url_decode);

sub _fetch_record {
    my ($id, $source) = @_;

    eval {
        return undef unless ($source =~ /^[a-zA-Z0-9]+$/);

        # check agency: crossref or datacite
        if ($source eq 'crossref') {
            $id =~ s{^\D+[:\/]}{};

            # Need to have an explicit Catmandu::Importer::getJSON
            # new instance to have access to the 'warn=>0' features
            # to switch of warning messages
            my $data = Catmandu::Importer::getJSON->new(
                'getJSON',
                from    => url_decode("https://api.crossref.org/works/$id/agency"),
                timeout => 10,
                warn    => 0 ,
            )->first;

            if (!$data) {
                $source = "crossref";
            }
            elsif (   $data->{message}
                && $data->{message}->{agency}->{id} eq "datacite")
            {
                $source = "datacite";
            }
            else {
                $source = "crossref";
            }
        }

        my $pkg
            = Catmandu::Util::require_package($source, 'LibreCat::FetchRecord');

        unless ($pkg) {
            h->log->error("failed to load LibreCat::FetchRecord::$source");
            return undef;
        }

        h->log->debug("Processing LibreCat::FetchRecord::$source $id");

        return $pkg->new->fetch($id);
    };
    if ($@) {
        h->log->error("Failed to fetch $id from $source");
        return undef;
    }
}

=head2 POST /librecat/record/import

Returns a form with imported data.

=cut

post '/librecat/record/import' => sub {
    my $p = params;
    trim($p, 'id',     'whitespace');
    trim($p, 'source', 'whitespace');

    state $bag = h->main_publication;
    my $user = h->get_person(session->{user_id});
    my $id   = $p->{id};
    my $data
        = request->upload('data')
        ? request->upload('data')->content
        : $p->{data};
    my $source = $p->{source};

    my $imported_records = _fetch_record($p->{id} // $data, $source);

    unless (Catmandu::Util::is_array_ref($imported_records)) {
        return template "backend/add_new",
            {
            error    => "Import from $source failed - try later again" ,
            imported => []
            };
    }

    for my $pub (@$imported_records) {
        $pub->{_id}    = $bag->generate_id;
        $pub->{status} = 'new'
            ; # new is the status of records not checked by users/reviewers
        $pub->{creator}
            = {id => session->{user_id}, login => session->{user}};
        $pub->{user_id}    = session->{user_id};
        $pub->{department} = $user->{department};

        # If we allow bulk imports, add all the imported records
        # otherwise return the first record
        if(h->config->{web_bulk_import} or !exists h->config->{web_bulk_import}){
          # Use config/hooks.yml to register functions
          # that should run before/after importing publications
          h->hook('import-new-' . $source)->fix_around(
            $pub,
            sub {
                publication->add($pub);
            }
          );
        }
        else {
          my $type = $pub->{type} || 'journal_article';
          my $templatepath = "backend/forms";
          $pub->{new_record} = 1;

          return template $templatepath . "/$type.tt", $pub;
        }
    }

    return template "backend/add_new",
        {
        ok => "Imported "
            . int(@$imported_records)
            . " record(s) from $source",
        imported => $imported_records
        };
};

1;
