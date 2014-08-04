package App::Catalog::Controller::Admin;

use Catmandu::Sane;
use Catmandu;
use App::Catalog::Helper;
use Hash::Merge qw/merge/;
use Carp;
use Exporter qw/import/;
our @EXPORT = qw/new_person search_person update_person edit_person delete_person/;
our @EXPORT_OK
    = qw/new_department update_department edit_department delete_department/;

our %EXPORT_TAGS = (
    all        => [ @EXPORT, @EXPORT_OK ],
    person     => [@EXPORT],
    department => [@EXPORT_OK],
);

# manage persons
sub _create_id_pers {
    my $bag = h->authority('admin')->get('1');
    my $id  = $bag->{"latest"};
    $id++;
    $bag = h->bag->add( { _id => "1", latest => $id } );
    return $id;   # correct?
}

sub new_person {
    return _create_id_pers;
}

sub search_person {
    my $p = shift;
    
    if ($p->{id}) {
        return [h->authority_admin->get($p->{id})];
    } elsif ($p->{full_name}) {
        return h->authority_admin->select("last_name", $p->{full_name})->to_array;
    } else {
        croak "Error: No search params provided";
    }
}

sub update_person {
    my $data = shift;
    croak "Error: No _id specified" unless $data->{_id};

    my $old = h->authority('admin')->get( $data->{_id} );
    my $merger = Hash::Merge->new();           #left precedence by default!
    my $new = $merger->merge( $data, $old );

    h->authority('admin')->add($new);
    h->authority('admin')->commit;
}

sub edit_person {
    my $id = shift;
    return h->authority_admin->get($id);
}

sub delete_person {
    my $id = shift;
    return "Error" unless $id;

    h->authority('admin')->delete($id);
    h->authority('admin')->commit;
}

# manage departments
sub _create_id_dep {
    my $bag = h->authority('department')->get('1');
    my $id  = $bag->{"latest"};
    $id++;
    $bag = h->bag->add( { _id => "1", latest => $id } );
    return $id;    # correct?
}

sub new_department {
    return _create_id_dep;
}

sub update_department {
    my $data = shift;
    return "Error: No _id specified" unless $data->{_id};

    my $old = h->authority('department')->get( $data->{_id} );
    my $merger = Hash::Merge->new();           #left precedence by default!
    my $new = $merger->merge( $data, $old );

    h->authority('department')->add($new);
    h->authority('department')->commit;
}

sub edit_department {
    my $id = shift;
    return 0 unless $id;

    return h->authority('department')->get($id);
}

sub delete_department {
    my $id = shift;
    return "Error" unless $id;

    h->authority('department')->delete($id);
    h->authority('department')->commit;
}

1;
