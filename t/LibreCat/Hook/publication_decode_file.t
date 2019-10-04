use strict;
use warnings FATAL => "all";
use Test::More;
use Test::Exception;

my $pkg;

BEGIN {
    $pkg = "LibreCat::Hook::publication_decode_file";
    use_ok $pkg;
}

require_ok $pkg;


is_deeply(
    $pkg->new()->fix({
        file => [ qq({ "access_level": "open_access", "relation": "main_file" }) ]
    }),
    {
        file => [{access_level => "open_access", relation => "main_file"}]
    },
    "multiple files are uploaded: record.file is an array of json strings"
);

is_deeply(
    $pkg->new()->fix({
        file => qq({ "access_level": "open_access", "relation": "main_file" })
    }),
    {
        file => [{access_level => "open_access", relation => "main_file"}]
    },
    "one file is uploaded: record.file is a single json string"
);

is_deeply(
    $pkg->new()->fix({
        file => [{access_level => "open_access", relation => "main_file"}]
    }),
    {
        file => [{access_level => "open_access", relation => "main_file"}]
    },
    "preserve record.file if everything is ok"
);

done_testing;
