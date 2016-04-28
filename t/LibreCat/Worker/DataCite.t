use Test::Lib;
use LibreCatTest;

my $pkg;
BEGIN {
    $pkg = 'LibreCat::Worker::DataCite';
    use_ok $pkg;
}

dies_ok { $pkg->new() };
dies_ok { $pkg->new(user => 'me') };
dies_ok { $pkg->new(password => 'secret') };
lives_ok { $pkg->new(user => 'me', password => 'secret') };

my $datacite =  $pkg->new(user => 'me', password => 'secret', test_mode => 1);

can_ok $datacite, $_ for qw(work mint metadata);

lives_ok {
    $datacite->work({doi => '10.4356', landing_url => 'example.com', datacite_xml => '<?xml ...'})
} "Calling work is safe.";

done_testing;
