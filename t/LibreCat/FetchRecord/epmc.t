use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use Test::TCP;
use t::HTTPServer;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Data::Dumper;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord::epmc';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok {$x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

test_tcp(
    client => sub {
       my $port = shift;
       my $x    = $pkg->new(baseurl => "http://127.0.0.1:$port");
       my $pub  = $x->fetch('27740824');

       ok $pub , 'got a publication';

       is $pub->[0]{title} , 'Numerical Evidence for a Phase Transition in 4D Spin-Foam Quantum Gravity.' , 'got a title';
       is $pub->[0]{type}, 'journal_article', 'type == journal_article';

       is_deeply $pub->[0]{author}, [
                          {
                            'full_name' => 'Bahr, B',
                            'last_name' => 'Bahr',
                            'first_name' => 'B'
                          },
                          {
                            'full_name' => 'Steinhaus, S',
                            'last_name' => 'Steinhaus',
                            'first_name' => 'S'
                          }
                        ] , 'got 2 authors';

       ok ! $x->fetch('6666');
    },
    server => sub {
       my $port = shift;
       t::HTTPServer->new(port => $port)->run(sub {;
           my $env = shift;
           if ($env->{QUERY_STRING} =~ /query=27740824/) {
               my $body = path("t/records/epmc.js")->slurp;
               return [ 200,
                   [ 'Content-Length' => length($body) ],
                   [ $body ]
               ];
           }
           else {
               my $body = 'bad boy';
               return [ 404,
                   [ 'Content-Length' => length($body) ],
                   [ $body ]
               ];
           }
       });
   }
);

done_testing;
