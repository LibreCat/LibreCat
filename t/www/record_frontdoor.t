use strict;
use warnings;

use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

use Test::More import => ['!pass'];
use Test::WWW::Mechanize::PSGI;

my $app = eval {do './bin/app.pl';};

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);

subtest "get frontdoor" => sub {
    $mech->get_ok("/record/2737383");

    $mech->has_tag("h1", "Function of glutathione peroxidases in legume root nodules");

    $mech->content_contains("LjGpx1 and LjGpx3 are nitrosylated in vitro");
};

done_testing;
