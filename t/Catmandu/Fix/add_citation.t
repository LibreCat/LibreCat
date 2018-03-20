package T::TestEngine;

use Moo;

sub create {
    my ($self,$data) = @_;
    +{ test => "this is a citation" };
}

package main;

use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::add_citation';
    use_ok $pkg;
};

require_ok $pkg;

is_deeply $pkg->new()->fix({ foo => 'bar'}), { foo => 'bar' };

is_deeply $pkg->new(citation_engine => T::TestEngine->new)
              ->fix({ foo => 'bar'}),
              {
                  foo => 'bar' ,
                  citation => { test => 'this is a citation' },
              };

done_testing;
