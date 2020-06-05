package LibreCat::App::Search::Route::oai_sru;

=head1 NAME

LibreCat::App::Search::Route::oai_sru - handles routes for SRU and OAI interfaces.

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use Dancer::Plugin::Catmandu::OAI;
use Dancer::Plugin::Catmandu::SRU;
use Catmandu::Util qw(:is);

=head2 GET /sru

Endpoint of the SRU interface.

=cut

sru_provider '/sru';

=head2 GET/POST /oai

Endpoint of the OAI interface.

=cut

hook before => sub {

    my $request     = request();
    my $env         = $request->env();
    my $path_info   = $request->path_info();

    #disable storing of sessions for /oai or /sru
    #note that the cookie is still sent
    if( $path_info eq "/oai" || $path_info eq "/sru" ){

        $env->{'psgix.session.options'} //= {};
        $env->{'psgix.session.options'}->{no_store} = 1;

    }

};

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
        && $pub->{file}->[0]->{access_level} eq 'open_access')
    {
        push @$specs, "$pub->{type}Ftxt", "driver", "open_access";
    }

    $specs;
    };

1;
