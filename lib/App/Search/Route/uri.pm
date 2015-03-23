package App::Search::Route::uri;

=head1 NAME

App::Search::Route::uri - sugar for nice URIs

=cut

use Catmandu::Sane;
use Catmandu;
use Dancer qw/:syntax/;

# hook before => sub {
#     my $header_accept = request->{accept} ||= '';
#     $header_accept =~ s/;.*//g;
#     my @accepts = split (',', $header_accept);
#     my %seen = ();
#     my @fmt_ok;
#     @fmt_ok = grep {$seen{$_}++} @accepts,  keys %{ h->config->{export}->{mime_types} };
#     if (@fmt_ok){
#         params->{fmt} = h->config->{export}->{mime_types}->{$fmt_ok[0]};
#     }
# };

get '/record/:id' => sub {
    forward '/publication/'.params->{id};
};

get '/download/:id/:file_id' => sub {
	my $path = h->host . 'myPUB/download/' . params->{'id'} . '/' . params->{'file_id'};
	redirect $path;
};

get '/dublin_core/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'dc'};
};

get '/dc/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'dc'};
};

get '/ris/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'ris'};
};

get '/bibtex/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'bibtex'};
};

get '/html/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'html'};
};

get '/dc_json/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'dc_json'};
};

get '/mods/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'mods'};
};

get '/json/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'json'};
};

get '/yaml/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'yaml'};
};

get '/rdf/:id' => sub {
    forward '/publication/'.params->{id}, {fmt => 'rdf'};
};

get '/department/rss/:id' => sub {
    my $id = param 'id';
    forward '/feed/daily', {q => "department exact $id"};
};

get '/person/rss/:id' => sub {
    my $id = param 'id';
    forward '/feed/daily', {q => "person exact $id"};
};

get '/type/:type' => sub {
	my $t = param 'type';
	forward '/publication', {q => "documenttype=$t"};
};

get '/year/:year' => sub {
	my $y = param 'year';
	forward '/publication', {q => "publishingYear exact $y"};
};

get '/oa' => sub {
	forward '/publication', {q => "fulltext exact 1"};
};

get '/oa/type/:type' => sub {
	my $t = param 'type';
	forward '/publication', {q => "fulltext exact 1 AND documenttype=$t"};
};

get '/oa/year/:year' => sub {
	my $y = param 'year';
	forward '/publication', {q => "fulltext exact 1 AND publishingYear exact $y"};
};

get '/oa/person/:id' => sub {
	my $id = param 'id';
	forward '/publication', {q => "fulltext exact 1 AND person exact $id"};
};

get '/oa/department/:id' => sub {
	my $id = param 'id';
	forward '/publication', {q => "fulltext exact 1 AND department exact $id"};
};

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
