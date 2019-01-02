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
    $pkg = 'LibreCat::Cmd::rac';
    use_ok $pkg;
}

require_ok $pkg;

my $bag = Catmandu->store('main')->bag('reqcopy');
$bag->delete_all;
my $dt = DateTime->now();
my $date_expires = $dt->add(days => librecat->config->{request_copy}->{period} - 1 )->ymd;
my $data = [
    {
        record_id => 1234,
        date_expires => '2015-01-01',
    },
    {
        record_id => 9876,
        date_expires => $date_expires,
    }
];
$bag->add_many($data);

my $result = test_app(qq|LibreCat::CLI| => ['rac']);
ok !$result->error, 'ok threw no exception';

is $bag->to_array->[0]->{record_id}, "9876", "record_id correct";

done_testing;
