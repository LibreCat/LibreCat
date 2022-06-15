use Catmandu::Sane;
use LibreCat -self => -load => {layer_paths => [qw(t/layer)]};
use LibreCat::Validator::JSONSchema;
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Model::User';
    use_ok $pkg;
}

require_ok $pkg;

my $user = $pkg->new(
    %{librecat->config->{user}},
    bag        => Catmandu->store('main')->bag('user'),
    search_bag => Catmandu->store('search')->bag('user'),
    validator  => LibreCat::Validator::JSONSchema->new(
        schema => Catmandu->config->{schemas}{user},
        namespace => "validator.jsonschema.errors"
    )
);

ok $user->does('LibreCat::Model');

ok my $u = $user->get(1234);

is $u->{_id}, '1234';

ok $u = $user->find_by_username('einstein');

is $u->{login}, 'einstein';

ok !$user->get('unknown_ID');

is_deeply(
    +{ $user->to_session( $u ) },
    +{
        role => "super_admin",
        user_id => "1234",
        user => "einstein",
        lang => "en",
        user_last_updated => $u->{date_updated}
    }
);

ok(
    $user->is_session({
        role => "super_admin",
        user_id => "1234",
        user => "einstein",
        lang => "en"
    })
);

ok(
    !($user->is_session({
        role => "super_admin",
        user_id => "1234",
        lang => "en"
    }))
);

is(
    $user->find_by_username("mozart"),
    undef,
    "find_by_username may not return inactive users"
);

done_testing;
