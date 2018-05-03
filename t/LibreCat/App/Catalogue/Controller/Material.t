use Catmandu::Sane;
use LibreCat load => (layer_paths => [qw(t/layer)]);
use LibreCat::App::Helper;
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::App::Catalogue::Controller::Material';
    use_ok $pkg;
}

require_ok $pkg;

use Data::Dumper;

create_dummy_publication('999000');
create_dummy_publication('999001');

note("creating a new relation");
{
    my $pub = get_dummy_publication('999000');

    $pub->{related_material}->{record} = [
        { id => '999001' , relation => 'earlier_version' , status => 'private' }
    ];

    update_related_material($pub);

    is_deeply $pub->{related_material}->{record} , [
        { id => '999001' , relation => 'earlier_version' , status => 'private'}
    ];

    my $pub2 = get_dummy_publication('999001');

    is_deeply $pub2->{related_material}->{record} , [
        { id => '999000' , relation => 'later_version' , status => 'private' }
    ] , 'found the reverse relation';

    save_dummy_publication($pub);
}

note("try adding double relationships");
{
    my $pub = get_dummy_publication('999000');

    $pub->{related_material}->{record} = [
        { id => '999001' , relation => 'earlier_version' , status => 'private' } ,
        { id => '999001' , relation => 'later_version' , status => 'private' }
    ];

    update_related_material($pub);

    is_deeply $pub->{related_material}->{record} , [
        { id => '999001' , relation => 'later_version' , status => 'private'}
    ];

    my $pub2 = get_dummy_publication('999001');

    is_deeply $pub2->{related_material}->{record} , [
        { id => '999000' , relation => 'earlier_version' , status => 'private' }
    ] , 'found the reverse relation';

    save_dummy_publication($pub);
}

note("updating existing relation");
{
    my $pub = get_dummy_publication('999000');

    $pub->{related_material}->{record} = [
        { id => '999001' , relation => 'contains' , status => 'private' }
    ];

    update_related_material($pub);

    is_deeply $pub->{related_material}->{record} , [
        { id => '999001' , relation => 'contains' , status => 'private'}
    ];

    my $pub2 = get_dummy_publication('999001');

    is_deeply $pub2->{related_material}->{record} , [
        { id => '999000' , relation => 'published_in' , status => 'private' }
    ] , 'found the reverse relation';

    save_dummy_publication($pub);
}

note("deleting relation");
{
    my $pub = get_dummy_publication('999000');

    $pub->{related_material}->{record} = [];

    update_related_material($pub);

    is_deeply $pub->{related_material}->{record} , [];

    my $pub2 = get_dummy_publication('999001');

    is_deeply $pub2->{related_material}->{record} , [] , 'deleted the reverse relation';
}

delete_dummy_publication('999000');
delete_dummy_publication('999001');

done_testing;

sub save_dummy_publication {
    my $pub = shift;
    h->main_publication->add($pub);
    h->main_publication->commit;
    h->publication->add($pub);
    h->main_publication->commit;
}

sub get_dummy_publication {
    my $id = shift;
    h->main_publication->get($id);
}

sub create_dummy_publication {
    my $id = shift;

    my $dummy_publication = {
        _id => $id ,
        status => 'private'
    };

    h->main_publication->add($dummy_publication);
    h->main_publication->commit;
    h->publication->add($dummy_publication);
    h->main_publication->commit;

    return $dummy_publication;
}

sub delete_dummy_publication {
    my $id = shift;

    h->main_publication->delete($id);
    h->main_publication->commit;
    h->publication->delete(999111999);
}
