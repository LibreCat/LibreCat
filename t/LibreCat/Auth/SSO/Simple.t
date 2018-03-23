use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Catmandu;
use Test::More;
use Test::Exception;
use Plack::Test;
use Plack::Builder;
use Plack::Session;
use HTTP::Request::Common;
use HTTP::Cookies;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Auth::SSO::Simple';
    use_ok $pkg;
}
require_ok $pkg;

use_ok "LibreCat";
LibreCat->load();

Catmandu->config->{store}->{builtin_users} = {
    package => 'Hash',
    options => {init_data => [{login => 'demo', password => 's3cret'}]}
};
Catmandu->config->{user}
    = {sources => [{store => "builtin_users", username_attr => "login"}]};

isa_ok(LibreCat->user, "LibreCat::User",
    "LibreCat->user returns a LibreCat::User");

$Plack::Test::Impl = "MockHTTP";
my $auth;
my $uri_base = "http://localhost.local";

lives_ok(sub {$auth = $pkg->new(uri_base => $uri_base);},
    "created instance for package $pkg");

can_ok($auth, "to_app");
isa_ok $auth, "LibreCat::Auth::SSO::Simple";

my $app;

lives_ok(sub {$app = $auth->to_app;}, "convert instance $pkg to plack app");

lives_ok(
    sub {

        $app = builder {
            enable "Session";
            mount "/auth/test" => sub {
                my $env = shift;

                my $session = Plack::Session->new($env);
                $session->set(
                    "auth_sso",
                    +{
                        package    => "Plack::Auth::SSO::CAS",
                        package_id => "Plack::Auth::SSO::CAS",
                        response =>
                            {content => "", content_type => "text/xml"},
                        extra => {},
                        info  => {},
                        uid   => "demo"
                    }
                );

                [
                    302,
                    [
                        "Content-Type" => "text/html",
                        Location       => "$uri_base/session/sso"
                    ],
                    []
                ];
            };
            mount "/session/sso" => $app;
            mount "/"            => sub {

                my $env     = shift;
                my $session = Plack::Session->new($env);
                my $user    = $session->get("user");
                my $user_id = $session->get("user_id");
                my $role    = $session->get("role");

                my $status
                    = is_string($user)
                    && is_string($user_id)
                    && is_string($role) ? 200 : 403;
                my $body = $status == 200 ? "welcome" : "access denied";

                [$status, ["Content-Type" => "text/plain"], [$body]];

            };
        };

    },
    "created full test app"
);

my $test;
my $cookies = HTTP::Cookies->new();

lives_ok(sub {$test = Plack::Test->create($app);}, "created Plack::Test");

my $res = $test->request(GET "$uri_base/session/sso");

is $res->header("location"), "$uri_base/access_denied",
    "/session/sso should redirect to /access_denied when no session";

$res = $test->request(GET "$uri_base/");

is $res->code, 403, "/ should return status 403 when no session";

$res = $test->request(GET "$uri_base/auth/test");

is $res->header("location"), "$uri_base/session/sso",
    "/auth/test should redirect to /session/sso";

$cookies->extract_cookies($res);

my $req = GET "$uri_base/session/sso";
$cookies->add_cookie_header($req);

$res = $test->request($req);

is $res->header("location"), "$uri_base/",
    "/session/sso should redirect to / when session";

done_testing;
