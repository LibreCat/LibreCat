use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use Test::More;
use File::Slurp;

my @worker_pkg;

BEGIN {
    @worker_pkg = map {
        $_ =~ s/\.pm$//;
        'LibreCat::Validator::' . $_;
    } read_dir('lib/LibreCat/Validator/');

    use_ok $_ for @worker_pkg;
}

require_ok $_ for @worker_pkg;

{
    my $x = LibreCat::Validator::Researcher->new;

    ok $x , 'got a researcher validator';

    my @white_list = $x->white_list;

    ok @white_list > 0 , 'got a non-empty white list';

    # Check for some fields
    ok grep(/^login$/,@white_list) , 'found login in white list';
    ok grep(/^password$/,@white_list) , 'found password in white list';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data({
        _id            => '1234'   ,
        account_status => 'active' ,
        account_type   => 'external' ,
        first_name     => 'Donald' ,
        last_name      => 'Duck'   ,
        full_name      => 'Donald Fauntleroy Duck' ,
    });

    ok ! $errors2 , 'got no errors';
}

{
    my $x = LibreCat::Validator::Research_group->new;

    ok $x , 'got a research_group validator';

    my @white_list = $x->white_list;

    ok @white_list > 0 , 'got a non-empty white list';

    # Check for some fields
    ok grep(/^name$/, @white_list) , 'found name in white list';
    ok grep(/^department$/, @white_list) , 'found department in white list';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data({
        _id =>  '1234' ,
        name => 'Ducks inc.'
    });

    ok ! $errors2 , 'got no errors';
}

{
    my $x = LibreCat::Validator::Department->new;

    ok $x , 'got a department validator';

    my @white_list = $x->white_list;

    ok @white_list > 0 , 'got a non-empty white list';

    # Check for some fields
    ok grep(/^name$/, @white_list) , 'found name in white list';
    ok grep(/^display/, @white_list) , 'found display in white list';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data({
        _id   =>  '1234' ,
        name  => 'Duck Library' ,
        layer => 1 ,
        tree  => [ { _id => '1234' } ]
    });

    ok ! $errors2 , 'got no errors';
}

{
    my $x = LibreCat::Validator::Project->new;

    ok $x , 'got a project validator';

    my @white_list = $x->white_list;

    ok @white_list > 0 , 'got a non-empty white list';

    # Check for some fields
    ok grep(/^name$/, @white_list) , 'found name in white list';
    ok grep(/^description/, @white_list) , 'found description in white list';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data({
        _id   =>  '1234' ,
        name  => 'Duck Project' ,
    });

    ok ! $errors2 , 'got no errors';
}

{
    my $x = LibreCat::Validator::Publication->new;

    ok $x , 'got a publication validator';

    my @white_list = $x->white_list;

    ok @white_list > 0 , 'got a non-empty white list';

    # Check for some fields
    ok grep(/^title/, @white_list) , 'found title in white list';
    ok grep(/^author/, @white_list) , 'found author in white list';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data({
        _id    =>  '1234' ,
        type   => 'journal_article' ,
        year   => 2016 ,
        status => 'private' ,
        title  => 'Quack quack quack' ,
    });

    ok ! $errors2 , 'got no errors';
}

done_testing;
