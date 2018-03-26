use strict;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use Test::TCP;
use HTTPServer;
use Path::Tiny;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::arxiv';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok {$x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

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
