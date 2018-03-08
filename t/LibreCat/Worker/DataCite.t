use Catmandu::Sane;
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::DataCite';
    use_ok $pkg;
}

require_ok $pkg;

dies_ok {$pkg->new()} "missing user/password";
dies_ok {$pkg->new(user => 'me')} "missing password";
dies_ok {$pkg->new(password => 'secret')} "missing user";
lives_ok {$pkg->new(user => 'me', password => 'secret')} "object lives with user/password";

my $datacite = $pkg->new(user => 'me', password => 'secret', test_mode => 1);

can_ok $datacite, $_ for qw(work mint metadata);

my $user = $ENV{DATACITE_USER} || "";
my $password = $ENV{DATACITE_PASSWORD} || "";

my $datacite_xml=<<EOF;
<resource xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://datacite.org/schema/kernel-4" xsi:schemaLocation="http://datacite.org/schema/kernel-4 http://schema.datacite.org/meta/kernel-4.1/metadata.xsd">
<identifier identifierType="DOI">10.5072/LibreCatTestDOI871263127836</identifier>
<creators>
<creator>
<creatorName nameType="Personal">Fosmire, Michael</creatorName>
<givenName>Michael</givenName>
<familyName>Fosmire</familyName>
</creator>
<creator>
<creatorName nameType="Personal">Wertz, Ruth</creatorName>
<givenName>Ruth</givenName>
<familyName>Wertz</familyName>
</creator>
<creator>
<creatorName nameType="Personal">Purzer, Senay</creatorName>
<givenName>Senay</givenName>
<familyName>Purzer</familyName>
</creator>
</creators>
<titles>
<title xml:lang="en">Critical Engineering Literacy Test (CELT)</title>
</titles>
<publisher>Purdue University Research Repository (PURR)</publisher>
<publicationYear>2013</publicationYear>
<subjects>
<subject xml:lang="en">Assessment</subject>
<subject xml:lang="en">Information Literacy</subject>
<subject xml:lang="en">Engineering</subject>
<subject xml:lang="en">Undergraduate Students</subject>
<subject xml:lang="en">CELT</subject>
<subject xml:lang="en">Purdue University</subject>
</subjects>
<language>en</language>
<resourceType resourceTypeGeneral="Dataset">Dataset</resourceType>
<version>1.0</version>
<descriptions>
<description xml:lang="en" descriptionType="Abstract">
We developed an instrument, Critical Engineering Literacy Test (CELT), which is a multiple choice instrument designed to measure undergraduate students’ scientific and information literacy skills. It requires students to first read a technical memo and, based on the memo’s arguments, answer eight multiple choice and six open-ended response questions. We collected data from 143 first-year engineering students and conducted an item analysis. The KR-20 reliability of the instrument was .39. Item difficulties ranged between .17 to .83. The results indicate low reliability index but acceptable levels of item difficulties and item discrimination indices. Students were most challenged when answering items measuring scientific and mathematical literacy (i.e., identifying incorrect information).
</description>
</descriptions>
</resource>
EOF

SKIP: {
    skip "No DataCite environment settings found (DATACITE_USER, DATACITE_PASSWORD).",
        5 if (!$user || !$password);

    my $registry = $pkg->new(user => $user, password => $password, test_mode => 1);

    my $res = $registry->work({
        doi => "10.5072/LibreCatTestDOI871263127836",
        landing_url => "http://pub.uni-bielefeld.de/mytest/dataset",
        datacite_xml => $datacite_xml,
    });

    ok $res;
}

done_testing;
