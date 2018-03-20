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
    $pkg = 'LibreCat::FetchRecord::crossref';
    use_ok $pkg;
}

require_ok $pkg;

my $x;

lives_ok {$x = $pkg->new()} 'lives_ok';

can_ok $pkg, $_ for qw(fetch);

test_tcp(
    client => sub {
       my $port = shift;
       my $x    = $pkg->new(baseurl => "http://127.0.0.1:$port/works/");
       my $pub  = $x->fetch('10.1002/0470841559.ch1');

       ok $pub , 'got a publication';

       is $pub->[0]{title} , 'Network Concepts' , 'got a title';
       is $pub->[0]{type}, 'book_chapter', 'type == book_chapter';

       ok ! $x->fetch('6666');
    },
    server => sub {
       my $port = shift;
       t::HTTPServer->new(port => $port)->run(sub {;
           my $env = shift;
           if ($env->{REQUEST_URI} =~ /\/works\/10.1002%2F0470841559.ch1/) {
               my $body = path("t/records/crossref.js")->slurp_utf8;
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
