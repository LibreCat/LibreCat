use strict;
use warnings;
use Test::More;
use App::Catalog::Controller::Admin qw/:all/;

# new_person
#my $new = new_person;


# import_person
my $p = import_person('86212');
is ($p->{_id}, '86212', "ID ok");
like ($p->{first_name}, qr/\w+/, "First name ok");
like ($p->{last_name}, qr/\w+/, "Last name ok");


done_testing;
