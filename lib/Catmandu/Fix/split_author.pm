package Catmandu::Fix::split_author;

use Catmandu::Sane;
use Moo;
use Catmandu::Fix::Has;

has source => (fix_arg => 1);

sub fix {
    my ($self, $pub) = @_;

    if ($self->source eq 'epmc') {
        if ($pub->{author}) {
            my @au = split(/, /,$pub->{author});
            delete $pub->{author};

            foreach my $a (@au) {
                $a =~ /(\w+)\s(\w+)/;
                push @{$pub->{author}}, {full_name => "$1, $2", first_name => $2, last_name => $1};
            }
        }

        return $pub;
    } elsif ($self->source eq 'inspire') {
        if (my $tmp_au = $pub->{author}) {
            delete $pub->{author};
            $tmp_au = (ref $tmp_au eq 'ARRAY') ? ($tmp_au) : ([$tmp_au]);
            foreach my $a (@{$tmp_au}) {
                $a =~ /(\w+),\s(\w+)/;
                push @{$pub->{author}}, {full_name => $a, first_name => $2, last_name => $1};
            }
        }
        return $pub;
    }

}

1;
