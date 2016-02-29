package Catmandu::Fix::person;

use Catmandu::Sane;
use Moo;

sub fix{
    my ($self, $data) = @_;
    my @p = qw(author editor translator supervisor honoree);

    foreach my $pers (@p) {
        next unless $data->{$pers};
        
        @{$data->{$pers}} = grep defined, @{$data->{$pers}};
        my $splice_me;
        my $i = 0;
        
        foreach (@{$data->{$pers}}){
            if ($_->{first_name} and $_->{last_name}) {
                $_->{full_name} = $_->{last_name} . ", " . $_->{first_name};
                $i++;
            }
            else {
                push @$splice_me, $i;
            }
        }
        
        if($splice_me){
            foreach (@$splice_me){
                splice @{$data->{$pers}}, $_, 1;
            }
        }
    }
    return $data;
}

1;
