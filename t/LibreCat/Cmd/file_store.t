use Catmandu::Sane;
use Path::Tiny;
use LibreCat -self => -load => {layer_paths => [qw(t/layer)]};

use LibreCat::CLI;
use Test::More;
use Test::Exception;
use App::Cmd::Tester::CaptureExternal;

use utf8;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Cmd::file_store';
    use_ok $pkg;
}

require_ok $pkg;

my $publications = librecat->model("publication");
$publications->delete_all();

{
    use_ok "LibreCat::Audit";
    LibreCat::Audit->new()->delete_all();
}

note("no command");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store']);

    ok $result->exit_code, 'exit !0';

    ok $result->error, 'ok threw an exception';
}

note("help");
{
    my $result = test_app(qq|LibreCat::CLI| => ['help', 'file_store']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'ok threw no exception';

    my $output = $result->stdout;
    like $output, qr/Usage:/, "Help message";
}

note("unknown command");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'do_nonsense']);

    ok $result->exit_code, 'exit !0';

    ok $result->error, 'invalid command threw an exception';

    like $result->error, qr/should be one of/, "error message of invalid command";
}

note("list");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'list']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'list threw no exception';

    my $output = $result->stdout;

    is $output , "", 'got no files';
}

note("list wrong store");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','list','--store','idontexist']);

    ok $result->exit_code, 'exit !0';

    ok $result->error, 'ok threw an exception';
}

note("add 1234 poem.txt before adding publication record");
{
    my $result = test_app(
        qq|LibreCat::CLI| => ['file_store', 'add', '1234', 't/records/poem.txt']);

    ok $result->exit_code, 'exit !0';

    ok $result->error, 'ok threw an exception';

}

$publications->add({ type => "book", _id => "1234", title => "1234", status => "private" });

note("add 1234 poem.txt after adding publication record");
{
    my $result = test_app(
        qq|LibreCat::CLI| => ['file_store', 'add', '1234', 't/records/poem.txt']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'add threw no exception';

    ok -r 't/data/000/001/234/poem.txt', 'got a file';
}

note("list");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'list']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'list threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^000001234/, 'listing of 1234';
}

note("list --store default");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'list','--store','default']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'list threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^000001234/, 'listing of 1234';
}

note("get wrong key");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'get', '9999']);

    ok $result->exit_code, 'exit !0';

    ok $result->error, 'get threw exception';
}

note("get 1234");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'get', '1234']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'get threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/^key: 1234/, 'get 1234';
}

note("fetch wrong key");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'get', '9999', 'poem.txt']);

    ok $result->exit_code, 'exit !0';

    ok $result->error, 'fetch threw exception';
}

note("get wrong file");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'get', '1234','idontexist']);

    ok $result->exit_code, 'exit !0';

    ok $result->error, 'get threw exception';
}

note("fetch 1234 poem.txt");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'get', '1234', 'poem.txt']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'get threw no exception';

    my $output = $result->stdout;

    ok $output , 'got an output';

    #  App::Cmd::Tester::CaptureExternal requires decoding content
    utf8::decode($output);

    like $output , qr/.*床前明月光.*/, 'correct content';
}

note("exists 1234");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'exists', '1234']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'exists threw no exception';

    my $output = $result->stdout;
    ok $output , 'got an output';

    like $output , qr/\d+ EXISTS/, 'exists 1234';
}

## The copy code forks a new process which messes up the testing of all the rest
#note("copy 1234");
#{
#    my $result = test_app(qq|LibreCat::CLI| => ['file_store', 'copy', '1234', 'test']);
#
#    ok !$result->exit_code, 'exit 0';
#
#    ok !$result->error, 'exists threw no exception';
#}

note("delete 1234 poem.txt");
{
    my $result = test_app(
        qq|LibreCat::CLI| => ['file_store', 'delete', '1234', 'poem.txt']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'delete threw no exception';

    ok !-r 't/data/000/001/234/poem.txt', 'file is gone';
}

note("purge 1234");
{
    my $result
        = test_app(qq|LibreCat::CLI| => ['file_store', 'purge', '1234']);

    ok !$result->exit_code, 'exit 0';

    ok !$result->error, 'purge threw no exception';

    my $output = $result->stdout;

    is $output , "purged 1234\n", 'got no output';

    ok !-d 't/data/000/001/234', 'container is gone';
}

note("is audit empty");
{
    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        0,
        "audit is empty"
    );
}

note("add with audit");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','add','--log','add_file','1234','t/records/poem.txt']);

    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        1,
        "file_store add: adds message for add"
    );
}

note("get with audit");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','get','--log','get_container_info','1234']);

    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        2,
        "file_store get: add message for get"
    );
}

note("fetch with audit");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','get','--log','fetch_container_file','1234','poem.txt']);

    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        3,
        "file_store get: add message for get"
    );
}

note("delete with audit");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','delete','--log','delete_file','1234','poem.txt']);

    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        4,
        "file_store delete file: add message for delete"
    );
}

note("purge with audit");
{
    my $result = test_app(qq|LibreCat::CLI| => ['file_store','purge','--log','remove_container','1234']);

    is(
        LibreCat::Audit->new()->select( bag => "publication" )->select( id => 1234 )->count(),
        5,
        "file_store purge: add message for purge"
    );
}

done_testing;
