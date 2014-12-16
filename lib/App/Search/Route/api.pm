package App::Search::Route::api;

=head1 NAME

  App::Search::Route::api - handles routes for SRU and OAI interfaces.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use lib qw(/home/vitali/projects/LibreCat/Dancer-Plugin-Catmandu-OAI/lib);
use Dancer::Plugin::Catmandu::OAI;
use Dancer::Plugin::Catmandu::SRU;

=head2 GET /sru

  Endpoint of the SRU interface.

=cut
sru_provider '/sru';

=head2 GET/POST /oai

  Endpoint of the OAI interface.

=cut
oai_provider '/oai',
    deleted => sub {
        defined $_[0]->{date_deleted};
    },
    set_specs_for => sub {
        my $pub = $_[0];
        my $specs = [$pub->{type}];

        if ($pub->{ec_funded} && $pub->{ec_funded} eq '1') {
            if ($pub->{type} eq 'researchData') {
                push @$specs, "openaire_data";
            } else {
                push @$specs, "openaire";
            }
	    }

        if ($pub->{file}->[0]->{open_access} && $pub->{file}->[0]->{open_access} eq '1') {
            push @$specs, "$pub->{type}Ftxt", "driver", "open_access";
        }
        $specs;
    };

1;
