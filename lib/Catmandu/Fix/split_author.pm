package Catmandu::Fix::split_author;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $pub) = @_;

    if ($pub->{author}) {
        my @au = split(/, /,$pub->{author});
        delete $pub->{author};

        foreach my $a (@au) {
            $a =~ /(\w+)\s(\w+)/;
            push @{$pub->{author}}, {full_name => $a, first_name => $2, last_name => $1};
        }
    }

    return $pub;
}

1;
