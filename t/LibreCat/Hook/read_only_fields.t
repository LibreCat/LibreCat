use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use Clone qw(clone);
use LibreCat::App::Helper;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Hook::read_only_fields';
    use_ok $pkg;
}
require_ok $pkg;

my $x;
lives_ok {$x = $pkg->new()} 'lives_ok';

can_ok $x, 'fix';

my $store = Catmandu->store('main')->bag('publication');
my $pub   = Catmandu->importer('YAML', file => 't/records/valid-publication.yml')->first;

# Add some sample date
$store->add($pub);
$store->commit;

my $pub_orig   = clone($pub);
my $id         = $pub->{_id};
my $orig_title = $pub->{title};

ok $orig_title , "publication has title: $orig_title";

note("change title");
$pub->{title} = 'This is a new title';

my $fixed_pub = $x->fix($pub);

ok $fixed_pub , 'fix()';
is $fixed_pub->{title} , 'This is a new title' , 'title has changed';

note("set a read_only title field");
h->config->{hook}->{read_only_fields} = [qw(title)];

$fixed_pub = $x->fix($pub);
ok $fixed_pub , 'fix()';
is $fixed_pub->{title} , $orig_title , 'title has not changed';

note("check if an admin changed the record");
ok !$x->is_admin($pub), 'ok no admin changed this record';

$pub->{user_id} = '1234';

ok $x->is_admin($pub), 'ok now we have an admin change';

# Clean up...

$store->delete($id);
$store->commit;

done_testing;
