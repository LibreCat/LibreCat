#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Catmandu;
use Path::Tiny;
use utf8;

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Plugin::DynamicChecksum';
    use_ok $pkg;
}
require_ok $pkg;

my $store = Catmandu->store(
        'File::Simple',
        root    => 't/data3',
        default_plugins => [ 'DynamicChecksum']
    );

ok $store , 'created a store with a DynamicChecksum';

my $files = $store->index->files('000000001');

ok $files , 'got files';

ok $files->can('checksum') , 'can(checksum)';

my $checksum = $files->checksum('publication.pdf');

is $checksum , '3bc23505ac519f3d476d4b2d78802e75' , 'got the right checksum';

my $file = $files->get('publication.pdf');

ok $file;

my $checksum2 = Catmandu::Plugin::DynamicChecksum::dynamic_checksum($files,$file);

is $checksum2 , '3bc23505ac519f3d476d4b2d78802e75' , 'got the right checksum';

done_testing;
