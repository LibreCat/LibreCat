use Catmandu::Sane;
use Test::More;
use Test::Exception;
use Path::Tiny;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use utf8;

my $pkg;
my @worker_pkg;

BEGIN {
    $pkg = 'LibreCat::App::Helper';
    use_ok $pkg;
}

require_ok $pkg;

ok h , 'got a helper';

isa_ok h->log , 'Log::Log4perl::Logger' , 'h->log';

is ref(h->config) , 'HASH' , 'h->config';

is h->config->{store}->{main}->{options}->{data_source} ,
   'dbi:SQLite:dbname=t/tmp/librecat_test.sqlite3' ,
   'Can read config->store->main->options->data_source';

isa_ok h->hook('publication-update') ,
    'LibreCat::Hook',
    'h->hook';

isa_ok h->queue ,
    'LibreCat::JobQueue',
    'h->queue';

isa_ok h->layers,
    'LibreCat::Layers',
    'h->layers';

isa_ok h->create_fixer('blabalbla') ,
    'Catmandu::Fix' ,
    'h->create_fixer(blabalbla)';

my $fix = h->create_fixer('test.fix');

isa_ok $fix , 'Catmandu::Fix' , 'h->create_fixer(test.fix)';

is $fix->fix({})->{magic} , 'hello, world!' , 'the correct fix';

is_deeply h->alphabet , ['A'...'Z'] , 'h->alphabet';

note("main");

my $audit = h->main_audit;

ok $audit->does('Catmandu::Bag') , 'h->main_audit';

is $audit->name , 'audit';

my $publication = h->main_publication;

ok $publication->does('Catmandu::Bag') , 'h->main_publication';

is $publication->name , 'publication';

my $project = h->main_project;

ok $project->does('Catmandu::Bag') , 'h->main_project';

is $project->name , 'project';

my $user = h->main_user;

ok $user->does('Catmandu::Bag') , 'h->main_user';

is $user->name , 'user';

my $department = h->main_department;

ok $department->does('Catmandu::Bag') , 'h->main_department';

is $department->name , 'department';

my $research_group = h->main_research_group;

ok $research_group->does('Catmandu::Bag') , 'h->main_research_group';

is $research_group->name , 'research_group';

my $reqcopy = h->main_reqcopy;

ok $reqcopy->does('Catmandu::Bag') , 'h->main_reqcopy';

is $reqcopy->name , 'reqcopy';

note("search");

$publication = h->publication;

ok $publication->does('Catmandu::Bag') , 'h->publication';

is $publication->name , 'publication';

$project = h->project;

ok $project->does('Catmandu::Bag') , 'h->project';

is $project->name , 'project';

$user = h->user;

ok $user->does('Catmandu::Bag') , 'h->user';

is $user->name , 'user';

$department = h->department;

ok $department->does('Catmandu::Bag') , 'h->department';

is $department->name , 'department';

$research_group = h->research_group;

ok $research_group->does('Catmandu::Bag') , 'h->research_group';

is $research_group->name , 'research_group';

ok h->within_ip_range('157.193.101.1','157.193.0.0/16') , 'h->within_ip_range';

ok h->within_ip_range('157.193.101.1',['127.0.0.1','157.193.0.0/16']) , 'h->within_ip_range';

ok ! h->within_ip_range('157.193.101.1',['127.0.0.1','157.1.0.0/16']) , 'h->within_ip_range';

is_deeply h->string_array , [] , 'h->string_array';

is_deeply h->string_array('A') , ['A'] , 'h->string_array';

is_deeply h->string_array(['A']) , ['A'] , 'h->string_array';

is_deeply h->string_array([{A=>1},'A']) , ['A'] , 'h->string_array';

is_deeply h->nested_params({}) , {} , 'h->nested_params';

is_deeply h->nested_params({'a.0'=>1}) , {a => [1]} , 'h->nested_params';

is_deeply h->nested_params({'a.0'=>1,'b.0' => undef , 'c.0' => ''}) , {a => [1]} , 'h->nested_params';

is_deeply h->extract_params({}) , {cql => []} , 'h->extract_params';

is_deeply h->extract_params({
    start => 100 ,
    limit => 1000 ,
    lang  => 'eng' ,
    q     => 'test' ,
    cql   => 'abc' ,
    style => 'misc' ,
    sort  => 'title'
}) , {
    start => 100 ,
    limit => 1000 ,
    lang  => 'eng' ,
    q     => 'test' ,
    cql   => ['abc'] ,
    style => 'misc' ,
    sort  => ['title']
} , 'h->extract_params';

is_deeply h->extract_params({
    text  => 'a b c'
}) , {
    q     => ['a AND b AND c'] ,
    cql   => [] ,
} , 'h->extract_params';

like h->now , qr{^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$}, 'h->now';

is h->pretty_byte_size(1230231) , '1.23 MB' , 'h->pretty_byte_size';

{
    my $store = Catmandu->store('search')->bag('publication');
    my $pub   = Catmandu->importer('YAML', file => 't/records/valid-publication.yml')->first;
    my $id    = $pub->{_id};

    # Add some sample date
    $store->add($pub);
    $store->commit;

    sleep(2);

    ok h->get_publication($id) , 'h->get_publication';

    $store->delete($id);
    $store->commit;

    sleep(2);
}

ok !h->get_publication('999999999') , 'h->get_publication';

ok !h->get_person(0) , 'h->get_person';

my $person = h->get_person(1234);

ok $person , 'h->get_person';

is $person->{login} , 'einstein' , 'person = einstein';

{
    my $store = Catmandu->store('search')->bag('project');
    my $pub   = Catmandu->importer('YAML', file => 't/records/valid-project.yml')->first;
    my $id    = $pub->{_id};

    # Add some sample date
    $store->add($pub);
    $store->commit;

    sleep(2);

    ok h->get_project($id) , 'h->get_project';

    $store->delete($id);
    $store->commit;

    sleep(2);
}

ok !h->get_project(0) , 'h->get_project';

{
    my $store = Catmandu->store('search')->bag('department');
    my $pub   = Catmandu->importer('YAML', file => 't/records/valid-department.yml')->first;
    my $id    = $pub->{_id};

    # Add some sample date
    $store->add($pub);
    $store->commit;

    sleep(2);

    ok h->get_department($id) , 'h->get_department';

    $store->delete($id);
    $store->commit;

    sleep(2);
}

ok !h->get_department(0) , 'h->get_department';

ok h->get_list('language') , 'h->get_list';

is h->get_relation('relations_record','earlier_version')->{opposite} ,
   'later_version' , 'h->get_relation';

my $statistics = h->get_statistics;

ok $statistics , 'h->get_statistics';

ok exists $statistics->{publications} , '..publications';
ok exists $statistics->{researchdata} , '..researchdata';
ok exists $statistics->{oahits} , '..oahits';
ok exists $statistics->{projects} , '..projects';

like h->new_record , qr{^[A-Z0-9-]+$} , 'h->new_record';

{
    my $index = Catmandu->store('search')->bag('publication');
    my $store = Catmandu->store('main')->bag('publication');

    my $pub   = Catmandu->importer('YAML', file => 't/records/valid-publication.yml')->first;
    my $id    = $pub->{_id};

    $pub->{title} = '我能吞下玻璃而不伤身体';

    my $pub_stored = h->update_record('publication',$pub);

    ok $pub_stored , 'h->update_record';

    is $pub_stored->{title} , '我能吞下玻璃而不伤身体' , '..check title (return value)';

    is $store->get($id)->{title} , '我能吞下玻璃而不伤身体' , '..check title (main)';

    is $index->get($id)->{title} , '我能吞下玻璃而不伤身体' , '..check title (index)';

    $pub->{title} = 'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती';

    my $saved_record = h->store_record('publication',$pub);

    ok $saved_record , 'h->store_record';

    is $saved_record->{title} , 'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती' , '..check title (return value)';

    is $store->get($id)->{title} , 'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती' , '..check title (main)';

    is $index->get($id)->{title} , '我能吞下玻璃而不伤身体' , '..check title (index)';

    my $indexed_record = h->index_record('publication',$pub);

    ok $indexed_record , 'h->index_record';

    is $indexed_record->{title} , 'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती' , '..check title (return value)';

    is $store->get($id)->{title} , 'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती' , '..check title (main)';

    is $index->get($id)->{title} , 'मैं काँच खा सकता हूँ और मुझे उससे कोई चोट नहीं पहुंचती' , '..check title (index)';

    my $deleted_record = h->delete_record('publication',$id);

    ok $deleted_record , 'h->delete_record';

    is $deleted_record->{status} , 'deleted' , '..check status (return val)';

    is $store->get($id)->{status} , 'deleted' , '..check title (main)';

    is $index->get($id)->{status} , 'deleted' , '..check title (index)';

    ok h->purge_record('publication',$id) , 'h->purge_record';

    ok !$store->get($id) , '...purged (main)';

    ok !$index->get($id) , '...purged (index)';
}

is h->uri_base , 'http://localhost:5001' , 'h->uri_base';

is h->uri_for , 'http://localhost:5001' , 'h->uri_for()';

is h->uri_for('/foo') , 'http://localhost:5001/foo' , 'h->uri_for(/foo)';

is h->uri_for('/foo',{q => 'a',z => [1,2],我=>'能'}) ,
    'http://localhost:5001/foo?q=a&z=1&z=2&%E6%88%91=%E8%83%BD' ,
    'params with unicode characters encoded corectly by h->uri_for';

isa_ok h->get_file_store , 'Catmandu::Store::File::Simple' , 'h->get_file_store';

isa_ok h->get_access_store , 'Catmandu::Store::File::Simple' , 'h->get_access_store';

is h->file_extension('/foo/bar/test.pdf') , '.pdf' , 'h->file_extension';

is h->uri_for_file(123,456,'test.pdf') , 'http://localhost:5001/download/123/456.pdf' , 'h->uri_for_file';

ok h->can('my_helper'), 'load helpers';

done_testing;
