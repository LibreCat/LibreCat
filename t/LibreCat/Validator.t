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

note("Validate user");
{
    my $x = LibreCat::Validator::JSONSchema->new(schema => LibreCat->config->{schemas}{user});

    ok $x , 'got a user validator';

    my $whitelist = $x->whitelist;

    ok @$whitelist > 0, 'got a non-empty whitelist';

    # Check for some fields
    ok grep(/^login$/,    @$whitelist), 'found login in whitelist';
    ok grep(/^password$/, @$whitelist), 'found password in whitelist';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data(
        {
            _id            => '1234',
            account_status => 'active',
            account_type   => 'external',
            first_name     => 'Donald',
            last_name      => 'Duck',
            full_name      => 'Donald Fauntleroy Duck',
        }
    );

    ok !$errors2, 'got no errors';
}

note("Validate research_group");
{
    my $x = LibreCat::Validator::JSONSchema->new(schema => LibreCat->config->{schemas}{research_group});

    ok $x , 'got a research_group validator';

    my $whitelist = $x->whitelist;

    ok @$whitelist > 0, 'got a non-empty whitelist';

    # Check for some fields
    ok grep(/^name$/,       @$whitelist), 'found name in whitelist';
    ok grep(/^department$/, @$whitelist), 'found department in whitelist';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data(
        {_id => '1234', name => 'Ducks inc.', acronym => 'Quack'});

    ok !$errors2, 'got no errors';
}

note("Validate department");
{
    my $x = LibreCat::Validator::JSONSchema->new(schema => LibreCat->config->{schemas}{department});

    ok $x , 'got a department validator';

    my $whitelist = $x->whitelist;

    ok @$whitelist > 0, 'got a non-empty whitelist';

    # Check for some fields
    ok grep(/^name$/,   @$whitelist), 'found name in whitelist';
    ok grep(/^display/, @$whitelist), 'found display in whitelist';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data(
        {
            _id   => '1234',
            name  => 'Duck Library',
            layer => 1,
            tree  => [{_id => '1234'}]
        }
    );

    ok !$errors2, 'got no errors';
}

note("Validate project");
{
    my $x = LibreCat::Validator::JSONSchema->new(schema => LibreCat->config->{schemas}{project});

    ok $x , 'got a project validator';

    my $whitelist = $x->whitelist;

    ok @$whitelist > 0, 'got a non-empty whitelist';

    # Check for some fields
    ok grep(/^name$/,       @$whitelist), 'found name in whitelist';
    ok grep(/^description/, @$whitelist), 'found description in whitelist';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data({_id => '1234', name => 'Duck Project'});

    ok !$errors2, 'got no errors';
}

note("Validate publiction");
{
    my $x = LibreCat::Validator::JSONSchema->new(schema => LibreCat->config->{schemas}{publication});

    ok $x , 'got a publication validator';

    my $whitelist = $x->whitelist;

    ok @$whitelist > 0, 'got a non-empty whitelist';

    # Check for some fields
    ok grep(/^title/,  @$whitelist), 'found title in whitelist';
    ok grep(/^author/, @$whitelist), 'found author in whitelist';

    my $errors = $x->validate_data({});

    ok $errors , 'got errors';

    my $errors2 = $x->validate_data(
        {
            _id    => '1234',
            type   => 'journal_article',
            year   => 2016,
            status => 'private',
            title  => 'Quack quack quack',
        }
    );

    ok !$errors2, 'got no errors';
}

done_testing;
