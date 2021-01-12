package LibreCat::App::Catalogue::Route::importer;

=head1 NAME

LibreCat::App::Catalogue::Route::importer - central handler for import routes

=cut

use Catmandu::Sane;
use Catmandu::Util;
use LibreCat qw(publication);
use Catmandu::Fix::trim as => 'trim';
use Dancer ':syntax';
use LibreCat::App::Helper;
use URL::Encode qw(url_decode);
use Try::Tiny;
use File::Spec;

sub _fetch_record {
    my ($id, $source) = @_;

    try {
        return undef unless ($source =~ /^[a-zA-Z0-9]+$/);

        my $pkg;
        my $result;

        if ($source eq 'crossref') {
          $pkg = Catmandu::Util::require_package("crossref", 'LibreCat::FetchRecord');
          unless ($pkg) {
              h->log->error("failed to load LibreCat::FetchRecord::crossref");
              return undef;
          }

          h->log->debug("Processing LibreCat::FetchRecord::crossref $id");

          $result = $pkg->new->fetch($id);

          if($result->[0]->{agency} and $result->[0]->{agency} eq "unresolved"){
            $source = "datacite";

            $pkg = Catmandu::Util::require_package("datacite", 'LibreCat::FetchRecord');

            unless ($pkg) {
                h->log->error("failed to load LibreCat::FetchRecord::datacite");
                return undef;
            }

            h->log->debug("Processing LibreCat::FetchRecord::datacite $id");

            $result = $pkg->new->fetch($id);

          }

          return $result;

        }
        else {
          $pkg = Catmandu::Util::require_package($source, 'LibreCat::FetchRecord');

          unless ($pkg) {
              h->log->error("failed to load LibreCat::FetchRecord::$source");
              return undef;
          }

          h->log->debug("Processing LibreCat::FetchRecord::$source $id");

          return $pkg->new->fetch($id);
        }
    } catch {
        h->log->error("Failed to fetch $id from $source");
        return undef;
    }
}

=head2 GET /librecat/record/import

Returns again to the add record page

=cut
get '/librecat/record/import' => sub {
    # Required route for 'return_url' mechanism...
    redirect h->uri_for('/librecat/record/new');
};

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
    my $source = $p->{source} || "crossref";

    my $imported_records = _fetch_record($p->{id} // $data, $source);

    unless (Catmandu::Util::is_array_ref($imported_records)) {
        return template "backend/add_new",
            {
            error    => "Import from $source failed - try again later" ,
            imported => []
            };
    }

    my @saved_records = ();

    for my $pub (@$imported_records) {
        $pub->{_id}    = $bag->generate_id;
        $pub->{status} = 'new'
            ; # new is the status of records not checked by users/reviewers
        $pub->{creator}
            = {id => session->{user_id}, login => session->{user}};
        $pub->{user_id}    = session->{user_id};
        $pub->{department} = $user->{department};
        $pub->{message} = "$source Import";

        # If we allow bulk imports, add all the imported records
        # otherwise return the first record
        if(h->config->{web_bulk_import} or !exists h->config->{web_bulk_import}){
          # Use config/hooks.yml to register functions
          # that should run before/after importing publications
          h->hook('import-new-' . $source)->fix_around(
            $pub,
            sub {
                publication->add($pub ,
                    on_success => sub {
                        my ($rec) = @_;
                        push @saved_records , $rec;
                    }
                );
            }
          );
        }
        else {
          my $type = $pub->{type} || 'journal_article';
          var form_action => uri_for( "/librecat/record" );
          var form_method => "POST";
          var new_record  => 1;

          my $template = File::Spec->catfile(
              "backend","forms",$type
          );

          return template $template, $pub;
        }
    }

    my $errors = int(@$imported_records) - int(@saved_records);

    if ($errors) {
        return template "backend/add_new", {
            error => $errors == 1 ? "1 import failed" : "$errors imports failed"
        }
    }
    else {
        return template "backend/add_new",
        {
        ok => "Imported "
            . int(@saved_records)
            . " record(s) from $source",
        imported => \@saved_records ,
        };
    }
};

1;
