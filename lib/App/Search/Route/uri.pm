package App::Search::Route::uri;

=head1 NAME

App::Search::Route::uri - sugar for nice URIs

=cut

use Catmandu::Sane;
use Catmandu;
use Dancer qw(:syntax);

get '/pln/:year' => sub {
    my $y = param 'year';
    forward '/publication',
        {
            q => "fulltext exact 1 AND yearlastuploaded=$y",
            ftyp => "pln",
            limit => 1000,
        };
};

get '/pln_data/:year' => sub {
    my $y = param 'year';
    forward '/data',
        {
            q => "fulltext exact 1 AND yearlastuploaded=$y",
            ftyp => "pln",
            limit => 1000,
        };
};

1;
