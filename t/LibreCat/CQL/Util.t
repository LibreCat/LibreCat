use Catmandu::Sane;
use Test::More;

my $pkg;

BEGIN {
    $pkg = "LibreCat::CQL::Util";
    use_ok $pkg;
}

require_ok $pkg;

is(
    LibreCat::CQL::Util::cql_escape(qq(test)),
    qq(test)
);

is(
    LibreCat::CQL::Util::cql_escape(qq(test )),
    qq("test ")
);

is(
    LibreCat::CQL::Util::cql_escape(qq("test")),
    "\"\\\"test\\\"\""
);

is(
    LibreCat::CQL::Util::cql_escape(qq(test > 1)),
    qq("test > 1")
);

is(
    LibreCat::CQL::Util::cql_escape(qq(test > 1)),
    qq("test > 1")
);

is(
    LibreCat::CQL::Util::cql_escape(qq(test = 1)),
    qq("test = 1")
);


done_testing;
