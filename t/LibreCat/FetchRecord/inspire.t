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
    $pkg = 'LibreCat::FetchRecord::inspire';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok {$x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

test_tcp(
    client => sub {
        my $port = shift;
        my $x    = $pkg->new(baseurl => "http://127.0.0.1:$port/record/");
        my $pub  = $x->fetch('1632116');

        ok $pub , 'got a publication';

        is $pub->[0]{title}, 'Properties of expanding universes',
            'got a title';
        is $pub->[0]{type}, 'journal_article', 'type == journal_article';
        is_deeply $pub->[0]->{author},
            [{'first_name' => 'S.W.', 'last_name' => 'Hawking'}],
            'got an author';
        is $pub->[0]{external_id}->{inspire}->[0], 1632116,
            'got the inspire id';

        ok !$x->fetch('6666');
    },
    server => sub {
        my $port = shift;
        t::HTTPServer->new(port => $port)->run(
            sub {
                ;
                my $env = shift;
                if ($env->{REQUEST_URI} =~ /\/record\/1632116/) {
                    my $body = path("t/records/inspire.js")->slurp_utf8;
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
