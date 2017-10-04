use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat load => (layer_paths => [qw(t/layer)]);

my $pkg;

BEGIN {
    $pkg = 'Catmandu::Fix::add_urn';
    use_ok $pkg;
}
require_ok $pkg;

throws_ok {
    $pkg->new()->fix(
        {
            type => 'journal_article',
            file => [{access_level => 'open_access', relation => 'main_file'}]
        }
    );
}
qr /type and _id are required/, "caught missing _id";

throws_ok {
    $pkg->new()->fix(
        {
            _id  => 1,
            file => [{access_level => 'open_access', relation => 'main_file'}]
        }
    );
}
qr /type and _id are required/, "caught missing type";

is_deeply $pkg->new()->fix(
    {
        _id  => 1,
        type => 'journal_article',
        file => [{access_level => 'open_access', relation => 'main_file'}]
    }
    ),
    {
    _id  => 1,
    type => 'journal_article',
    file => [{access_level => 'open_access', relation => 'main_file'}],
    urn  => 'urn:whatever-11',
    },
    "add urn";

is_deeply $pkg->new()->fix(
    {
        _id  => 1,
        type => 'journal_article',
        file => [{access_level => 'closed', relation => 'main_file'}]
    }
    ),
    {
    _id  => 1,
    type => 'journal_article',
    file => [{access_level => 'closed', relation => 'main_file'}]
    },
    "do not add urn";

is_deeply $pkg->new()->fix(
    {
        _id  => 1,
        type => 'research_data',
        file => [{access_level => 'open_access', relation => 'main_file'}]
    }
    ),
    {
    _id  => 1,
    type => 'research_data',
    file => [{access_level => 'open_access', relation => 'main_file'}]
    },
    "do not add urn";

done_testing;
