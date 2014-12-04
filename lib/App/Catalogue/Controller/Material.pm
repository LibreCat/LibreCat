package App::Catalogue::Controller::Material;

use Catmandu::Sane;
use Catmandu;
use App::Helper;
use Furl;
use Carp;
use Exporter qw/import/;

our @EXPORT = qw/update_related_material/;

my %rel_map = (
    is_part_of => "has_part",
    has_part   => "is_part_of",
);

sub update_related_material {
    my $pub              = shift;
    my $related_material = $pub->{related_material};

    foreach my $rm (@$related_material) {

        # if link, check for valid
        if ( $rm->{link} && my $url = $rm->{link}->{url} ) {

            my $furl = Furl->new(
                agent   => 'Mozilla/20',
                timeout => 10,
            );

            my $res = $furl->get($url);
            die $res->status_line unless $res->is_success;
        }

        # set relation in other record
        if ( $rm->{record} && $rm->{record}->{id} ) {
            my $op = h->publications->get($rm->{record}->{id});

            push @{ $op->{related_material} },
                { record => { id => $pub->{_id}, relation => $rel_map{$rm->{record}->{relation}} } };
            h->publications->add($rec);
            h->publications->commit;
        }
    }
}

1;
