use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Auth::SSO::ORCID';
    use_ok $pkg;
}
require_ok $pkg;

dies_ok { $pkg->new() } 'client_id and client_secret required';
dies_ok { $pkg->new(client_id => 'freaky_app_123') } 'client_secret required';
dies_ok { $pkg->new(client_secret => 'secr3t') } 'client_id required';

lives_ok { $pkg->new(client_id => 'freaky_app_123', client_secret => 'secr3t') } 'lives ok';

done_testing;
