use strict;
use warnings FATAL => 'all';
use Catmandu;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use Data::Dumper;

my $pkg;
BEGIN {
    $pkg = "Catmandu::Exporter::RTF";
    use_ok $pkg;
}
require_ok $pkg;

lives_ok{ $pkg->new() } "lives ok";

my $data = Catmandu->importer('YAML', file => "t/records/valid-publication.yml")->first;

{
    my $file;
    my $rtf = $pkg->new(
        file => \$file,
    );

    $rtf->add($data);
    $rtf->commit;

    ok length($file) > 200, "content present";
    like $file, qr/HYPERLINK/, "linked title";
    unlike $file, qr/WoS/, "links";
}

{
    my $file;
    my $rtf = $pkg->new(
        file => \$file,
        style => "ama",
        name => "MyRepo",
    );

    $rtf->add($data);
    $rtf->commit;

    ok length($file) > 200, "content present";
    unlike $file, qr/HYPERLINK/, "linked title";
}

{
    my $file;
    my $rtf = $pkg->new(
        file => \$file,
        style => "ama",
        links => 1,
        name => "MyRepo",
    );

    $rtf->add($data);
    $rtf->commit;

    ok length($file) > 200, "content present";
    like $file, qr/WoS/, "WoS link";
    like $file, qr /HYPERLINK/, "links there"
}

done_testing;
