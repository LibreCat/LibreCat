use Catmandu::Sane;
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);

{
    my $layers = LibreCat->layers();
    my $loaded = LibreCat->loaded();
    is $loaded, 1, "layers loaded";
    is_deeply $layers->layer_paths, ["t/layer"], "test layer loaded";
}

# hooks
{
    dies_ok { LibreCat->hook(); } "no hook named";

    dies_ok { LibreCat->hook('iexist'); } "called fix does not exist";
}

{
    my $hook = LibreCat->hook('idontexist');

    is scalar(@{$hook->before_fixes}), 0;
    is scalar(@{$hook->after_fixes}),  0;

    my $data = {foo => 'bar'};
    $hook->fix_before($data);
    is_deeply($data, {foo => 'bar'});
}

{
    my $hook = LibreCat->hook('eat');
    is scalar(@{$hook->before_fixes}), 2;
    is scalar(@{$hook->after_fixes}),  1;
    my $data = {};
    $hook->fix_before($data);
    is_deeply($data, {peckish => 1, hungry => 1});
    $hook->fix_after($data);
    is_deeply($data, {satisfied => 1});
}


done_testing;
