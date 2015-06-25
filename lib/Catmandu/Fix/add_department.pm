package Catmandu::Fix::add_department;

use Catmandu::Sane;
use App::Helper;
use Dancer qw(:syntax);
use Moo;

sub fix {
    my ($self, $data) = @_;

    unless ($data->{department}) {
        my $person = h->get_person( session->{personNumber} );
        @{$data->{department}} = map {
            $_->{id};
        } @{$person->{department}};
    }
}

1;
