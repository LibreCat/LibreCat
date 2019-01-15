use strict;
use warnings FATAL => 'all';
use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use LibreCat -self;
use Catmandu;

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;
use DateTime;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::reqcopy';
    use_ok $pkg;
}

require_ok $pkg;

my $bag = Catmandu->store('main')->bag('reqcopy');

note("add test data");
{
    $bag->delete_all;
    my $dt = DateTime->now();
    my $date_expires = $dt->add(days => librecat->config->{request_copy}->{period} - 1 )->ymd;
    my $data = [
        {
            _id       => 1,
            record_id => 1234,
            date_expires => '2015-01-01',
        },
        {
            _id       => 2,
            record_id => 9876,
            date_expires => $date_expires,
        }
    ];
    $bag->add_many($data);
    $bag->commit;
}

note("list");
{
    my $result = test_app(qq|LibreCat::CLI| => ['reqcopy','list']);
    like $result->stdout , qr/count: 2/ , "found 2 hits";
}

note("get");
{
    my $result = test_app(qq|LibreCat::CLI| => ['reqcopy','get',1]);
    like $result->stdout , qr/2015-01-01/ , "found 1 hits";
}

note("expire");
{
    my $result = test_app(qq|LibreCat::CLI| => ['reqcopy','expire']);
    ok !$result->error, 'ok threw no exception';

    is $bag->to_array->[0]->{record_id}, "9876", "record_id correct";
}

note("delete");
{
    my $result = test_app(qq|LibreCat::CLI| => ['reqcopy','delete',2]);
    ok !$result->error, 'ok threw no exception';

    is $bag->count, "0", "deleted";
}

done_testing;
