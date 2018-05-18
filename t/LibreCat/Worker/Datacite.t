use Catmandu::Sane;
use Test::More;
use Test::Exception;
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Worker::DataCite';
    use_ok $pkg;
}

require_ok $pkg;

dies_ok {$pkg->new()} "missing user/password";
dies_ok {$pkg->new(user => 'me')} "missing password";
dies_ok {$pkg->new(password => 'secret')} "missing user";
lives_ok {$pkg->new(user => 'me', password => 'secret')}
"object lives with user/password";

my $datacite = $pkg->new(user => 'me', password => 'secret', test_mode => 1);

can_ok $datacite, $_ for qw(work mint metadata);

# SKIP: {
#     skip
#         "No DataCite environment settings found (DATACITE_USER, DATACITE_PASSWORD).",
#         5
#         if (!$user || !$password);
#
#     my $registry
#         = $pkg->new(user => $user, password => $password);
#
#     my $res = $registry->work(
#         {
#             doi          => "10.5072/LibreCatTest1234",
#             landing_url  => "http://pub.uni-bielefeld.de/mytest/dataset",
#             datacite_xml => $datacite_xml,
#         }
#     );
#
# note Dumper $res;
#     # ok $res;
#     # is_deeply $res, { mint => 200, metadata => 200}
# }


test_tcp(
    client => sub {
        my $port = shift;
        my $x    = $pkg->new(baseurl => "http://127.0.0.1:$port/api/query?");
        my $pub  = $x->fetch('arXiv:1609.0172');

        ok $pub , 'got a publication';

        is $pub->[0]{title},
            'The Good, the Bad, and the Ugly of Gravity and Information',
            'got a title';
        is $pub->[0]{type}, 'preprint', 'type == preprint';

        my $pub2 = $x->fetch('0000-0002-7970-7855');
        ok $pub2, 'got some publications';
        is $pub2 > 4, 1, 'more than one publication';

        ok !$x->fetch('6666');
    },
    server => sub {
        my $port = shift;
        t::HTTPServer->new(port => $port)->run(
            sub {
                ;
                my $env = shift;
                if ($env->{QUERY_STRING} =~ /1609\.0172/) {
                    my $body = path("t/records/arxiv-one.xml")->slurp_utf8;
                    return [200, ['Content-Length' => length($body)],
                        [$body]];
                }
                elsif ($env->{QUERY_STRING} =~ /0000-0002-7970-7855/) {
                    my $body = path("t/records/arxiv-orcid.xml")->slurp_utf8;
                    return [200, ['Content-Length' => length($body)],
                        [$body]];
                }
                else {
                    my $body = 'bad boy';
                    return [404, ['Content-Length' => length($body)],
                        [$body]];
                }
            }
        );
    }
);

done_testing;
