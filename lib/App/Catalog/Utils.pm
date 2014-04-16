package App::Catalog::Utils;

use Catmandu::Sane;
use Catmandu qw/load/;
use Moo;

has prefix => ( is => 'ro', required => 1 );
has id => (is => 'ro', required => 1);

sub genereteURN {
    my $self      = shift;
    my $nbn = $self->prefix . $self->id;
    my $weighting  = ' 012345678 URNBDE:AC FGHIJLMOP QSTVWXYZ- 9K_ / . +#';
    my $faktor     = 1;
    my $productSum = 0;
    my $lastcifer;
    foreach my $char ( split //, uc($nbn) ) {
        my $weight = index( $weighting, $char );
        if ( $weight > 9 ) {
            $productSum += int( $weight / 10 ) * $faktor++;
            $productSum += $weight % 10 * $faktor++;
        }
        else {
            $productSum += $weight * $faktor++;
        }
        $lastcifer = $weight % 10;
    }
    return $nbn . ( int( $productSum / $lastcifer ) % 10 );
}

1;
