use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Access';
    use_ok $pkg;
}

require_ok $pkg;

note("basic test");
{
    my $x = LibreCat::Access->new;
    ok $x;
    ok !$x->by_user_id({},{});
    ok !$x->by_user_role({},{});
}

note("user_id test");
{
    my $x = LibreCat::Access->new(allowed_user_id => [qw(creator author)]);

    ok $x ;
    ok $x->by_user_id(
        {
            creator => {
                id => 8008
            }
        } ,
        {
            _id => 8008
        }
    );
    ok ! $x->by_user_id(
        {
            creator => {
                id => 8008
            }
        } ,
        {
            _id => 6666
        }
    );

    ok $x->by_user_id(
        {
            creator => {
                id => 8008
            },
            author => [
                { id => 6666 }
            ]
        } ,
        {
            _id => 6666
        }
    );
}

note("user_role test");
{
    my $x = LibreCat::Access->new(
        allowed_user_id  => [qw(creator)] ,
        allowed_user_role => [qw(
                    reviewer
                    project_reviewer
                    data_manager
                    delegate
                    )]
    );

    ok $x ;
    ok $x->by_user_role(
        {
            department => [{_id => 8008}]
        } ,
        {
            reviewer => [
                { _id => 8008 }
            ]
        }
    );
    ok $x->by_user_role(
        {
            project => [{_id => 8008}]
        } ,
        {
            project_reviewer => [
                { _id => 8008 }
            ]
        }
    );
    ok ! $x->by_user_role(
        {
            department => [{_id => 8008}]
        } ,
        {
            data_manager => [
                { _id => 8008 }
            ]
        }
    );
    ok $x->by_user_role(
        {
            department => [{_id => 8008}] ,
            type => 'research_data'
        } ,
        {
            data_manager => [
                { _id => 8008 }
            ]
        }
    );
    ok $x->by_user_role(
        {
            creator => {
                id => 8008
            },
        } ,
        {
            delegate => [ 8008 ]
        }
    );
}

note("publication allow and deny");
{
    my $x = LibreCat::Access->new(
            allowed_user_id => [qw(creator author)] ,
            publication_allow => {
                foo => 'bar'
            }
    );
    ok $x ;
    ok !$x->by_user_id(
        {
            creator => {
                id => 8008
            }
        } ,
        {
            _id => 8008
        }
    );
    ok $x->by_user_id(
        {
            creator => {
                id => 8008
            } ,
            foo => 'bar'
        } ,
        {
            _id => 8008
        }
    );

    my $y = LibreCat::Access->new(
            allowed_user_id => [qw(creator author)] ,
            publication_deny => {
                foo => 'bar'
            }
    );
    ok $y ;
    ok $y->by_user_id(
        {
            creator => {
                id => 8008
            }
        } ,
        {
            _id => 8008
        }
    );
    ok !$y->by_user_id(
        {
            creator => {
                id => 8008
            } ,
            foo => 'bar'
        } ,
        {
            _id => 8008
        }
    );
}

done_testing;
