use Catmandu::Sane;
use Path::Tiny;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::file_store';
    use_ok $pkg;
}

require_ok $pkg;

{
    use_ok "LibreCat::Audit";
    LibreCat::Audit->new()->delete_all();
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store']);
    ok $result->error, 'ok threw an exception';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'file_store']);
    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'do_nonsense']);
    ok $result->error, 'invalid command threw an exception';

    like $result->error, qr/should be one of/, "error message of invalid command";
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'list']);

    ok !$result->error, 'list threw no exception';

    my $output = $result->stdout;

    is $output , "", 'got no files';
}

{
    my $result = test_app(
        qq|LibreCat::CLI| => ['file_store', 'add', '1234', 'cpanfile']);

    ok !$result->error, 'add threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^key: 1234/, 'added 1234';

    ok -r 't/data/000/001/234/cpanfile', 'got a file';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'list']);

    ok !$result->error, 'list threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^000001234/, 'listing of 1234';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'get', '1234']);

    ok !$result->error, 'get threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^key: 1234/, 'get 1234';
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'exists', '1234']);

    ok !$result->error, 'exists threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/\d+ EXISTS/, 'exists 1234';
}

{
    my $result = test_app(
        qq|LibreCat::CLI| => ['file_store', 'delete', '1234', 'cpanfile']);

    ok !$result->error, 'delete threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^key: 1234/, 'deleted 1234 cpanfile';

    ok !-r 't/data/000/001/234/cpanfile', 'file is gone';
}

{
    my $result
        = test_app(qq|LibreCat::CLI| => ['file_store', 'purge', '1234']);

    ok !$result->error, 'purge threw no exception';

    my $output = $result->stdout;

    is $output , "purged 1234\n", 'got no output';

    ok !-d 't/data/000/001/234', 'container is gone';
}

{
    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        0,
        "audit is empty"
    );
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','add','--log','add_file','1234','cpanfile']);

    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        2,
        "file_store add: adds message for add and get"
    );
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','get','--log','get_container_info','1234']);

    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        3,
        "file_store get: add message for get"
    );
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','delete','--log','delete_file','1234','cpanfile']);

    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        5,
        "file_store delete file: add message for delete and get"
    );
}

{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','purge','--log','remove_container','1234']);

    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        6,
        "file_store purge: add message for purge"
    );
}

done_testing;
