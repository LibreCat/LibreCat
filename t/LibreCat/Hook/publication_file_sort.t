use strict;
use warnings FATAL => 'all';
use Test::More;
use Test::Exception;
use LibreCat -load => {layer_paths => [qw(t/layer)]};

my $pkg;

BEGIN {
    $pkg = "LibreCat::Hook::publication_file_sort";
    use_ok $pkg;
}
require_ok $pkg;

is_deeply(
    $pkg->new()->fix({
        _id  => 1,
        type => "journal_article",
        file => [
            {
                file_name => "b.tif"
            },
            {
                file_name => "a.tif"
            }
        ]
    }),
    {
        _id  => 1,
        type => "journal_article",
        file => [
            {
                file_name => "a.tif"
            },
            {
                file_name => "b.tif"
            }
        ]
    }
);

is_deeply(
    $pkg->new()->fix({
        _id  => 1,
        type => "journal_article",
        file => [
            {
                file_name => "9.tif"
            },
            {
                file_name => "10.tif"
            }
        ]
    }),
    {
        _id  => 1,
        type => "journal_article",
        file => [
            {
                file_name => "10.tif"
            },
            {
                file_name => "9.tif"
            }
        ]
    }
);

is_deeply(
    $pkg->new()->fix({
        _id  => 1,
        type => "journal_article",
        file => [
            {
                file_name => "10.tif"
            },
            {
                file_name => "09.tif"
            }
        ]
    }),
    {
        _id  => 1,
        type => "journal_article",
        file => [
            {
                file_name => "09.tif"
            },
            {
                file_name => "10.tif"
            }
        ]
    }
);

#don't ask
is_deeply(
    $pkg->new()->fix({
        _id  => 1,
        type => "journal_article",
        file => [
            qq({ "file_name" : "10.tif", "title" : "café" }),
            qq({ "file_name" : "09.tif", "title" : "café" })
        ]
    }),
    {
        _id  => 1,
        type => "journal_article",
        file => [
            {
                file_name => "09.tif",
                title => "café"
            },
            {
                file_name => "10.tif",
                title => "café"
            }
        ]
    }
);

done_testing;
