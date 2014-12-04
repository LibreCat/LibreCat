package App::Catalog::Controller::InspireMonitor;

use Catmandu::Sane;
use Catmandu;

use Exporter qw/import/;

our @EXPORT    = qw/import_from_id/;
our @EXPORT_OK = qw/arxiv inspire crossref plos pubmed/;

1;
