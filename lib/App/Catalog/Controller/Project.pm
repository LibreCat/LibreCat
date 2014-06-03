package App::Catalog::Controller::Project;

use Catmandu::Sane;
use Catmandu;
use App::Catalog::Helper;
use Hash::Merge qw/merge/;
use Exporter qw/import/;

our @EXPORT = qw/new_project update_project edit_project delete_project/;

sub _create_id_proj {
    my $bag = h->project->get('1');
    my $id  = $bag->{"latest"};
    $id++;
    $bag = h->bag->add( { _id => "1", latest => $id } );
    return $id;
}

sub new_project {
    return _create_id_proj;
}

sub update_project {
    my $data = shift;
    return "Error: No _id specified" unless $data->{_id};

    my $old    = h->project->get( $data->{_id} );
    my $merger = Hash::Merge->new();              #left precedence by default!
    my $new    = $merger->merge( $data, $old );

    # need validation here?
    h->project->add($new);
}

sub edit_project {
    my $id = shift;
    return h->project->get($id);
}

sub delete_project {
    my $id = shift;
    return "Error" unless $id;

    h->project->delete($id);
    h->project->commit;
}

1;
