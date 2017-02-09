package LibreCat::App::Search::Route::api;

=head1 NAME

LibreCat::App::Search::Route::api - handles routes for SRU and OAI interfaces.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use Dancer::Plugin::Catmandu::OAI;
use Dancer::Plugin::Catmandu::SRU;
use Catmandu::Util qw(:is);
use Catmandu::Fix;
use LibreCat::App::Helper;
use LibreCat::Citation;

=head2 GET /sru

Endpoint of the SRU interface.

=cut

sru_provider '/sru';

=head2 GET/POST /oai

Endpoint of the OAI interface.

=cut

oai_provider '/oai', deleted => sub {
    defined $_[0]->{oai_deleted};
    },
    set_specs_for => sub {
    my $pub = $_[0];

    my $specs;
    push @$specs, $pub->{type}      if $pub->{type};
    push @$specs, $pub->{dini_type} if $pub->{dini_type};

    push @$specs, "ddc:$_" for @{$pub->{ddc}};

    if ($pub->{ec_funded} && $pub->{ec_funded} eq '1') {
        if ($pub->{type} eq 'research_data') {
            push @$specs, "openaire_data";
        }
        else {
            push @$specs, "openaire";
        }
    }

    if (   $pub->{type}
        && is_array_ref($pub->{file})
        && @{$pub->{file}} > 0
        && $pub->{file}->[0]->{open_access}
        && $pub->{file}->[0]->{open_access} eq '1')
    {
        push @$specs, "$pub->{type}Ftxt", "driver", "open_access";
    }

    $specs;
};

1;
