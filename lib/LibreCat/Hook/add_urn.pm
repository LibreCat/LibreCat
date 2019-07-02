package LibreCat::Hook::add_urn;

use Catmandu::Sane;
use LibreCat qw(config);
use Catmandu::Util qw(:is);
use Moo;
use JSON::MaybeXS qw();

has json => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        JSON::MaybeXS->new(utf8 => 0);
    },
    init_arg => undef
);

sub fix {
    my ($self, $data) = @_;

    return $data if $data->{urn};

    return $data unless ($data->{type} and $data->{_id});

    my @files;
    for (@{$data->{file}}) {
        if (is_string($_)) {
            push @files, $self->json()->decode($_);
        }
        else {
            push @files, $_;
        }
    }

    if (@files) {
        my $oa = 0;
        foreach my $f (@files) {
            if (    $f->{access_level} eq 'open_access'
                and $f->{relation} eq "main_file")
            {
                $oa = 1;
            }
        }

        if ($oa and $data->{type} ne 'research_data') {
            $data->{urn}
                = $self->_generate_urn(config->{urn_prefix}, $data->{_id});
        }
    }

    $data;
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

__END__


=pod

=head1 NAME

LibreCat::Hook::add_urn - creates a urn field from the input data

=head1 SYNOPSIS

    # in your config
    hooks:
      publication-update:
        before_fixes:
         - add_urn

=cut
