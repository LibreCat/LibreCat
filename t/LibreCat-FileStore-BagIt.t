#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Catmandu::Store::Hash;

use Data::Dumper;

my $pkg;
BEGIN {
    $pkg = 'LibreCat::FileStore::BagIt';
    use_ok $pkg;
}
require_ok $pkg;

my $store = $pkg->new(root => 't/local-store');

ok $store , 'created a store';

{
    my $container = $store->add('1235');

    ok $container , 'create the bag';
}

{
    my $container = $store->get('1235');

    ok $container , 'retrieve the bag';
}

{
    ok $store->exists('1235') , 'the bag exists';
}

ok $store->delete('1235') , 'remove the bag';

ok ! -r 'r/local-store/000/000/001/235' , 'deleted the bag';

done_testing;
