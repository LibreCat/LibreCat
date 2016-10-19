BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use lib path(__FILE__)->parent->parent->child('lib')->stringify;
    use LibreCat::Layers;

    LibreCat::Layers->new(layer_paths => [qw(t/layer)])->load;
}

use Catmandu::Sane;
use Test::More;
use LibreCat;

# hooks

my $hook = LibreCat->hook('eat');
is scalar(@{$hook->before_fixes}), 2;
is scalar(@{$hook->after_fixes}), 1;
my $data = {};
$hook->fix_before($data);
is_deeply($data, {peckish => 1, hungry => 1});
$hook->fix_after($data);
is_deeply($data, {satisfied => 1});

done_testing;
