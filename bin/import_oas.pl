#!/usr/bin/env perl

use Catmandu::Sane;
use Catmandu -load;
use Moo;
use MooX::Options;
use LWP::UserAgent;

option from => (
    is => 'ro',
    required => 1,
    short => 'f',
    format => 's',
    doc => "Specify the start date (YYYY-MM-DD)",
    );
option until => (
    is => 'ro',
    required => 1,
    short => 'u',
    format => 's',
    doc => "Specify the end date (YYYY-MM-DD)",
);

option dry => (
    is => 'ro',
    doc => "Dry run. Does not import data to db but prints data to stdout.",
);

Catmandu->load(':up');
my $conf = Catmandu->config;

sub run {
    my ($self) = @_;

    my $from = $self->from;
    my $until = $self->until;

    my $browser = LWP::UserAgent->new;
    my $req =  HTTP::Request->new( GET => "https://oase.gbv.de/api/v1/reports/basic.json?identifier=oai%3Apub.uni-bielefeld.de%3A%25&from=$from&until=$until&granularity=month&content=counter%2Ccounter_abstract");
    $req->authorization_basic($conf->{oa_stats}->{user}, $conf->{oa_stats}->{passwd});
    my $json = $browser->request( $req )->content || die $@;

    if ($self->dry) {
        print $json;
        exit;
    }

    my $bag = Catmandu->store('metrics')->bag('oa_stats');

    Catmandu->importer('JSON', multiline => 1, file => \$json)->each(sub {
      my $rec = $_[0];
      foreach my $item (@{$rec->{entries}}) {
        $bag->add($item);
      }
    });

    $bag->commit;
}

main->new_with_options->run;

1;
