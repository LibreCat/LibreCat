use Catmandu::Sane;
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::DataCite';
    use_ok $pkg;
}

dies_ok {$pkg->new()};
dies_ok {$pkg->new(user => 'me')};
dies_ok {$pkg->new(password => 'secret')};
lives_ok {$pkg->new(user => 'me', password => 'secret')};

my $datacite = $pkg->new(user => 'me', password => 'secret', test_mode => 1);

can_ok $datacite, $_ for qw(work mint metadata);

done_testing;
