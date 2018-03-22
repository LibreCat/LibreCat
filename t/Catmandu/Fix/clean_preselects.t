use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::clean_preselects';
    use_ok $pkg;
};

require_ok $pkg;

note("abstract");

is_deeply $pkg->new()
              ->fix({
                  abstract => [
                    { lang => 'eng' , text => 'test' }
                  ]
              }),
              {
                  abstract => [
                    { lang => 'eng' , text => 'test' }
                  ]
              };

is_deeply $pkg->new()
            ->fix({
                abstract => [
                  { lang => 'eng' } ,
                  { lang => 'eng' , text => 'test' } ,
                  { lang => 'eng' } ,
                  { lang => 'eng' , text => 'test2' } ,
                ]
            }),
            {
                abstract => [
                  { lang => 'eng' , text => 'test' } ,
                  { lang => 'eng' , text => 'test2' } ,
                ]
            };

is_deeply $pkg->new()
              ->fix({
                  abstract => [
                    { lang => 'eng' }
                  ]
              }),
              {
              };

note("related_material");

is_deeply $pkg->new()
              ->fix({
                  related_material => {
                      link => [
                        { relation => 'test' , url => 'test' }
                      ]
                  }
              }),
              {
                  related_material => {
                      link => [
                        { relation => 'test' , url => 'test' }
                      ]
                  }
              };

is_deeply $pkg->new()
            ->fix({
                related_material => {
                    link => [
                      { relation => 'test' } ,
                      { relation => 'test' , url => 'test' } ,
                      { relation => 'test' } ,
                    ]
                }
            }),
            {
                related_material => {
                    link => [
                      { relation => 'test' , url => 'test' }
                    ]
                }
            };

is_deeply $pkg->new()
            ->fix({
                related_material => {
                    link => [
                      { relation => 'test' } ,
                      { relation => 'test' } ,
                    ]
                }
            }),
            {
                related_material => {}
            };

note("do nothing on rest");
is_deeply $pkg->new()->fix({ foo => 'bar'}) , { foo => 'bar'};

done_testing;
