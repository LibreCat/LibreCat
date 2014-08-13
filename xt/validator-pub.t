#/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my $pkg;
BEGIN {
	$pkg = 'Catmandu::Validator::PUB';
	use_ok $pkg;
}
require_ok $pkg;

my $v = $pkg->new(error_field => 1);

can_ok $v, 'validate_data';
can_ok $v, 'is_valid';
can_ok $v, 'valid_count';
can_ok $v, 'invalid_count';

#throws_ok { $v->new(handler => 1) } qr/handler should be a CODE reference/;

my $rec = {_id => "123", doi => "http://doi.org/10.412.28433",
volume => "2"};

is $v->is_valid($rec), 1, "Valid ok";
$v->last_errors;
my $rec2 = {_id => "3243", issue => "Ajd342"};

is $v->is_valid($rec2), 0;

# is $v->validate({field => 3}), undef, 'validate - fails';

# is_deeply $v->last_errors, ['Not 1'], 'last_errors returns error message';


done_testing;