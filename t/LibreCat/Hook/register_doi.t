use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Hook::register_doi';
    use_ok $pkg;
}
require_ok $pkg;

my $x;
lives_ok {$x = $pkg->new()} 'lives_ok';

can_ok $x, 'fix';

# We don't test enything in this testst because the hook  only sends data
# to the job queue which does the real work...

note("fake test without doi config");
{
    ok $x->fix({});
}

note("fake test with doi config");
{

    LibreCat->config->{doi} = {
        prefix => "0.000/test" ,
        queue  => "test" ,
        default_publisher => "LibreCat Publishing System"
    };

    ok $x->fix({});
}

note("fake test with even fake data");
{
    my $res = $x->fix({_id => 1234567890 , doi => '0.000/test/1234', status => 'public'});

    is $res->{publisher} ,  "LibreCat Publishing System";
}

done_testing;
