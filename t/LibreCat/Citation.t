use Catmandu::Sane;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Citation';
    use_ok $pkg;
}

require_ok $pkg;

lives_ok { $pkg->new } 'lives_ok';

my $rec = Catmandu->importer('YAML', file => 't/records/valid-publication.yml')->first;

subtest 'engine none' => sub {
    Catmandu->config->{citation}->{engine} = 'none';

    my $c = $pkg->new;
    ok !$c->create($rec), "engine set to 'none'";
};

subtest 'no engine set' => sub {
    Catmandu->config->{citation}->{engine} = undef;

    my $c = $pkg->new;
    ok !$c->create($rec), "engine not defined";
};

SKIP: {
    skip("No variable CSL_TEST set", 5) unless $ENV{CSL_TEST};

    Catmandu->config->{citation}->{engine} = 'csl';

    subtest 'styles' => sub {
        my $c = $pkg->new;
        my $style_obj = $c->create($rec);
        ok $style_obj, "default style";

        $c = $pkg->new(style => 'whatever');
        $style_obj = $c->create($rec);
        ok !$style_obj, "unknown style";

        $c = $pkg->new(style => 'ama', locale => 'de');
        $style_obj = $c->create($rec);
        ok $style_obj, "style with locale";

        $c = $pkg->new(all => 1);
        $style_obj = $c->create($rec);
        ok $style_obj, "all styles";
    };
}

done_testing;
