package Catmandu::Fix::add_urn;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Carp;
use Moo;

sub fix {
    my ($self, $pub) = @_;

    return $pub if $pub->{urn};

    unless ($pub->{type} and $pub->{_id}) {
        croak "type and _id are required.";
    }

    if ($pub->{file}) {
        my $oa = 0;
        foreach my $f (@{$pub->{file}}) {
            if (    $f->{access_level} eq 'open_access'
                and $f->{relation} eq "main_file")
            {
                $oa = 1;
            }
        }

        if ($oa and $pub->{type} ne 'research_data') {
            $pub->{urn}
                = $self->_generate_urn(h->config->{urn_prefix}, $pub->{_id});
        }
    }

    $pub;
}

sub _generate_urn {
    my ($self, $prefix, $id) = @_;
    my $nbn        = $prefix . $id;
    my $weighting  = ' 012345678 URNBDE:AC FGHIJLMOP QSTVWXYZ- 9K_ / . +#';
    my $faktor     = 1;
    my $productSum = 0;
    my $lastcifer;
    foreach my $char (split //, uc($nbn)) {
        my $weight = index($weighting, $char);
        if ($weight > 9) {
            $productSum += int($weight / 10) * $faktor++;
            $productSum += $weight % 10 * $faktor++;
        }
        else {
            $productSum += $weight * $faktor++;
        }
        $lastcifer = $weight % 10;
    }
    return $nbn . (int($productSum / $lastcifer) % 10);
}

1;
