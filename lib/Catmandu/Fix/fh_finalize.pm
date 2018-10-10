package Catmandu::Fix::fh_finalize;

use Catmandu::Sane;
use Catmandu;
use Moo;
use Catmandu::Fix::Has;

has store => (fix_opt => 1, default => sub { "main"; } );

has bag   => (fix_opt => 1, default => sub { "publication"; });

# restore values using the old record
sub finish {

    my( $self, $record ) = @_;

    state $bag = Catmandu->store( $self->store )->bag( $self->bag );

    my $old_record = $bag->get( $record->{_id} );

    if( $old_record ){

        $record->{date_created} = $old_record->{date_created};

    }

    $record;

}

sub fix {

    my ($self, $record) = @_;

    $self->finish( $record );

}

1;
