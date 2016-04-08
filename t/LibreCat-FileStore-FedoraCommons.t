#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use IO::File;
use Catmandu;
use Data::Dumper;

Catmandu->load('.');

my $pkg;
BEGIN {
    $pkg = 'LibreCat::FileStore::FedoraCommons';
    use_ok $pkg;
}
require_ok $pkg;

SKIP: {
	my $conf = Catmandu->config->{filestore}->{fedora};

	unless ($ENV{FEDORA_NETWORK_TEST}) {
        skip( "No network. Set FEDORA_NETWORK_TEST to run these tests.", 5 );
    }

    my $store = $pkg->new(%{$conf->{options}});

	ok $store , 'filestore->new';

	note("add container");
	{
	    my $container = $store->add('999000999');

	    ok $container , 'filestore->add';
	}

	note("get container");
	{
	    my $container = $store->get('999000999');

	    ok $container , 'retrieve the bag';

	    is $container->key , '999000999' , 'container->key';
	    ok $container->modified     , 'container->modified';
	    ok $container->created      , 'container->created'; 
	}

	note("exists container");
	{
	    ok $store->exists('999000999') , 'filestore->exists';
	}

	note("update container with files");
	{
		my $container = $store->get('999000999');

		is_deeply [$container->list] , [] , 'container->list';

		ok $container->add("poem.txt",poem()) , 'container->add';

		my @list = $container->list;

		ok @list == 1 , 'got one item in the container';

		my $file = $list[0];

		is ref($file) , 'LibreCat::FileStore::File::FedoraCommons' , 'item is a FileStore::File';

		is $file->key  , 'poem.txt' , 'file->key';
		is $file->size , length(poem()) , 'file->size';

		ok $container->commit , 'container->commit';

		$file = $container->get("poem.txt");

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

		$file = $container->get("poem2.txt");

		ok $file , 'container->get (poem2)';

		is $file->key  , 'poem2.txt' , 'file->key';
		is $file->size , length(poem()) , 'file->size';

		is $file->fh->getline , "Roses are red,\n" , 'file->fh->getline';
	}

	note("delete container");
	{
		ok $store->delete('999000999') , 'filestore->delete';
	}

	$store->delete('999000999');
}

done_testing;

sub poem {
	my $str =<<EOF;
Roses are red,
Violets are blue,
Sugar is sweet,
And so are you.
EOF
	$str;
}