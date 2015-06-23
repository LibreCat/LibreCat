#!/usr/bin/env perl

use Test::More;

my $pkg;
BEGIN {
    $pkg = 'Catmandu::Fix::person';
    use_ok $pkg;
}
require_ok $pkg;

my $data = {author => [{first_name => 'Larry', last_name => 'Wall'}]};

is_deeply $pkg->new()->fix($data),
    {author => [{first_name => 'Larry', last_name => 'Wall', full_name => 'Wall, Larry'}]};
