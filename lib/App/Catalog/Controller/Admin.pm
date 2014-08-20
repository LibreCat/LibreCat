package App::Catalog::Controller::Admin;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Importer::XML;
use Furl;
use Hash::Merge qw/merge/;
use Carp;
use Exporter qw/import/;

use App::Catalog::Helper;

our @EXPORT
    = qw/new_person search_person update_person edit_person delete_person import_person/;
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
    return $id;    # correct?
}

sub new_person {
    return "AU_". _create_id_pers;
}

sub search_person {
    my $p = shift;

    if ( $p->{_id} ) {
        return [ h->getPerson( $p->{_id} ) ];
    }
    elsif ( $p->{full_name} ) {
        return h->authority_admin->select( "full_name", qr/$p->{full_name}/i )
            ->to_array;
    }
    else {
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

sub import_person {
    my $id = shift;

    my $furl = Furl->new(agent => "Chrome 35.1",timeout => 10);

    my $base_url = 'http://ekvv.uni-bielefeld.de/ws/pevz';
    my $url  = $base_url . "/PersonKerndaten.xml?persId=$id";
    my $url2 = $base_url . "/PersonKontaktdaten.xml?persId=$id";

    my $res = $furl->get($url);
    croak "Error: $res->status_line" unless $res->is_success;
    my $p1 = Catmandu->importer('pevz', file => $res->content)->first;

    $res = $furl->get($url2);
    croak "Error: $res->status_line" unless $res->is_success;
    my $p2 = Catmandu->importer('pevz', file => $res->content)->first;
    my $merger = Hash::Merge->new();
    # decode_entities($email) if $email; # do we need this?
    return $merger->merge( $p1, $p2 );

# decode_entities($email) if $email;
# my $former = ( $res2 =~ /<\/pevz:kontakte>/ ) ? "0" : "1";
# my $nonexist = ( $former and !$personName ) ? "1" : "0";
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
