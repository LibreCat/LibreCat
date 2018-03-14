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
    $pkg = 'LibreCat::FetchRecord::datacite';
    use_ok $pkg;
}

require_ok $pkg;

test_tcp(
    client => sub {
       my $port = shift;
       my $x    = $pkg->new(baseurl => "http://127.0.0.1:$port/");
       my $pub  = $x->fetch('10.6084');

       ok $pub , 'got a publication';

       is $pub->[0]{title} , 'Gravity as Entanglement, and Entanglement as Gravity' , 'got a title';
       is $pub->[0]{type}, 'research_data', 'type == research_data';

       ok ! $x->fetch('10.6085');
       ok ! $x->fetch('6666');
    },
    server => sub {
       my $port = shift;
       t::HTTPServer->new(port => $port)->run(sub {;
           my $env = shift;
           if ($env->{PATH_INFO} =~ /10\.6084/) {
               my $body = path("t/records/datacite.xml")->slurp;
               return [ 200,
                   [ 'Content-Length' => length($body) ],
                   [ $body ]
               ];
           }
           elsif ($env->{PATH_INFO} =~ /10\.6085/) {
               my $body = '';
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
