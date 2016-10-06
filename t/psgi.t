BEGIN {
    use Catmandu::Sane;
    use Path::Tiny;
    use LibreCat::Layers;
    LibreCat::Layers->new(layer_paths => [qw(t/layer)])->load;
}

use Plack::Test;
use Test::More;
use Path::Tiny;
use Plack::Util;
use HTTP::Request;

my $app = Plack::Util::load_psgi(
    path(__FILE__)->parent->parent->child('bin')->child('app.pl')->stringify);

# test CSRF

test_psgi $app, sub {
    my $cb = shift;
    my ($req, $res);

    $req = HTTP::Request->new(GET => 'http://localhost/login');
    $res = $cb->($req);
    like $res->content, qr/input type="hidden" name="csrf_token/,
        'forms have csrf token';

    $req = HTTP::Request->new(POST => 'http://localhost/login');
    $res = $cb->($req);
    is $res->code, 403, 'POST without csrf token is forbidden';
};

done_testing;
