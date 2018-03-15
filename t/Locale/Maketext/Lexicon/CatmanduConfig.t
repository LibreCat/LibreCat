use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'Locale::Maketext::Lexicon::CatmanduConfig';
    use_ok $pkg;
};

require_ok $pkg;

my $lexicon = Locale::Maketext::Lexicon::CatmanduConfig->parse('en');

ok $lexicon, "lexicon exists";

is $lexicon->{hello}, "How are you?", "get corret value from lexicon";

done_testing;
