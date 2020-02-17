use Catmandu::Sane;
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Permission';
    use_ok $pkg;
};

require_ok $pkg;

lives_ok { $pkg->new(model => 'publication') } "valid model";
dies_ok { $pkg->new(model => 'some_model') } "dies on invalid model";

my $pm = $pkg->new(model => 'publication');
ok $pm->can_edit('publication', '1234', {user_id => 1, role => 'user'});

ok !$pm->can_download('publication', '1234', {user_id => 1, role => 'user'});

done_testing;
