use Catmandu::Sane;
use File::Slurp 'read_file';
use LibreCat load => (layer_paths => [qw(t/layer)]);
use LibreCat::Validator::Publication;
use Test::More;
use YAML::XS;
use all qw(LibreCat::FetchRecord::*);

my $yaml = do { local $/; <main::DATA> };
my $data = Load $yaml;

my $validator = LibreCat::Validator::Publication->new;
foreach my $source (sort keys %$data) {

    if (ref $data->{$source} eq 'HASH' &&  $data->{$source}->{file}) {
        my $pkg = "LibreCat::FetchRecord::$source";
        my $x = $pkg->new();

        my $content = read_file($data->{$source}->{file});
        my $pub = $x->fetch($content);
        ok $pub;

        # mock _id
        foreach my $entry (@$pub) {
            $entry->{_id} = 1;
            my $errors = $validator->validate_data($entry);
            note @$errors if $errors;

            ok ! $errors , "got no errors for $source, title: ". $entry->{title};
        }
    }
    elsif (ref $data->{$source} eq 'ARRAY') {
        foreach my $d (@{$data->{$source}}) {
            my $pkg = "LibreCat::FetchRecord::$source";
            my $x = $pkg->new();

            my $pub = $x->fetch($d);
            ok $pub;
            ok $pub->[0];

            # mock _id
            $pub->[0]->{_id} = 1;
            my $errors = $validator->validate_data($pub->[0]);
            note @$errors if $errors;

            ok ! $errors , "got no errors for $source : $d";
        }
    }
}

done_testing;

__DATA__
arxiv:
  - 1704.01052
  - 1704.01050
  - 1704.01073
  - 1501.01172
  - 1501.01646
  - 1501.02173
  - 1001.1131
  - 1001.1241
  - 1001.1786
  - 1001.2231
bibtex:
  file: xt/sample.bib
crossref:
  - 10.1017/cbo9780511526169.002
  - 10.1364/ao.53.003758
  - 10.1007/978-1-4612-1262-1_3
  - 10.2478/qmetro-2014-0001
  - 10.1002/9781118161968.app1
  - 10.2307/2532201
  - 10.1007/978-1-4612-6275-6_3
  - 10.1002/9781118161968.ch1
  - 10.1007/bf01233426
  - 10.3724/sp.j.1300.2013.13083
datacite:
  - 10.5523/BRIS.DOBUVUU00MH51Q773BO8YBKDZ
  - 10.18159/SNSN
  - 10.15778/RESIF.ZI2001
  - 10.15778/RESIF.ZF2015
  - 10.14470/MM7557265463
  - 10.14470/6T569239
  - 10.14470/MN7557778612
  - 10.14470/3S7550699980
  - 10.14470/FX099882
  - 10.18434/T4359D
epmc:
  - 27515114
  - 28059794
  - 27375217
  - 27387827
  - 27936349
  - 27720381
  - 25883881
  - 26162018
  - 25158076
  - 25633989
inspire:
  - 1589642
  - 1589520
  - 1589571
  - 1589466
  - 724189
  - 397723
  - 624951
  - 502686
  - 393386
  - 523423
# wos:
#   file: sample.wos
