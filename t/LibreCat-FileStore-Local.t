#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Catmandu::Store::Hash;

my $pkg;
BEGIN {
    $pkg = 'LibreCat::FileStore::Local';
    use_ok $pkg;
}
require_ok $pkg;

my $files = LibreCat::FileStore::Local->new(path => '/data2/librecat');

ok $files , "got a $pkg";

done_testing;
