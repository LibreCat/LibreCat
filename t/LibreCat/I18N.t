use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::I18N';
    use_ok $pkg;
}

require_ok $pkg;

dies_ok {$pkg->new()} "required argumentes missing";
lives_ok {$pkg->new(locale => 'en')} "lives_ok";

my $i18n = $pkg->new(locale => 'en');
can_ok $i18n, "localize";
is $i18n->localize('hello'), 'How are you?', "read correct lexicon";

done_testing;
