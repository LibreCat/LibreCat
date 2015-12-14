#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use IO::File;
use File::Path qw(remove_tree);
use Catmandu::Store::Hash;

use Data::Dumper;

my $pkg;
BEGIN {
    $pkg = 'LibreCat::FileStore::BagIt';
    use_ok $pkg;
}
require_ok $pkg;

my $store = $pkg->new(root => 't/local-store');

ok $store , 'filestore->new';

{
    my $container = $store->add('1235');

    ok $container , 'filestore->add';

    ok -r 't/local-store/000/000/001/235' , 'found a new bag';
}

{
    my $container = $store->get('1235');

    ok $container , 'retrieve the bag';

    is $container->key , '1235' , 'container->key';
    ok $container->modified     , 'container->modified';
    ok $container->created      , 'container->created'; 
}

{
    ok $store->exists('1235') , 'filestore->exists';
}

{
	my $container = $store->get('1235');

	is_deeply [$container->list] , [] , 'container->list';

	ok $container->add("poem.txt",poem()) , 'container->add';

	my @list = $container->list;

	ok @list == 1 , 'got one item in the container';

	my $file = $list[0];

	is ref($file) , 'LibreCat::FileStore::File::BagIt' , 'item is a FileStore::File';

	is $file->key  , 'poem.txt' , 'file->key';
	is $file->size , length(poem()) , 'file->size';

	# Not yet created anything on disk
	ok ! $file->created , '! file->created';
	ok ! $file->modified , '! file->modified';

	ok $container->commit , 'container->commit';

	ok -r 't/local-store/000/000/001/235/data/poem.txt' , 'found a poem.txt on disk';

	my $file = $container->get("poem.txt");

	ok $file , 'container->get';

	is $file->key  , 'poem.txt' , 'file->key';
	is $file->size , length(poem()) , 'file->size';

	# Now we have something on disk
	ok $file->created , 'file->created';
	ok $file->modified , 'file->modified';

	ok $container->add("poem2.txt", IO::File->new("t/poem.txt")) , 'adding a new file';

	@list = $container->list;

	ok @list == 2 , 'now we have 2 things in the list';

	ok $container->commit , 'container->commit';

	ok -r 't/local-store/000/000/001/235/data/poem.txt' , 'found a poem.txt on disk';
	ok -r 't/local-store/000/000/001/235/data/poem2.txt' , 'found a poem2.txt on disk';

	my $file = $container->get("poem2.txt");

	ok $file , 'container->get (poem2)';
}

ok $store->delete('1235') , 'filestore->delete';

ok ! -r 't/local-store/000/000/001/235' , 'deleted the bag';

done_testing;

remove_path("t/local-store");

sub remove_path {
    my $path = shift;
    # Stupid chdir trick to make remove_tree work
    chdir("lib");
    if (-d "../$path") {
       remove_tree("../$path");
    }
    chdir("..");
}

sub poem {
	my $str =<<EOF;
Roses are red,
Violets are blue,
Sugar is sweet,
And so are you.
EOF
	$str;
}
