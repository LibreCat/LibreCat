package Catmandu::Fix::split_author;

use Catmandu::Sane;
use Moo;
use Catmandu::Fix::trim as => 'trim';

sub fix {
    my ($self, $pub) = @_;

    foreach my $entity ( qw(author editor) ) {
        if (my $au = $pub->{$entity}) {
            delete $pub->{$entity};

            $au = (ref $au eq 'ARRAY') ? ($au) : ([$au]);
            foreach my $a (@$au) {
                if ($a =~ /(\w+\s*-*.*?)\s(\w+-*\w+)$/) {
                    push @{$pub->{$entity}}, {full_name => "$1, $2", first_name => trim $2, last_name => trim $1};
                } elsif ($a =~ /(\w+),\s(\w+)/) {
                    push @{$pub->{$entity}}, {full_name => trim $a, first_name => trim $2, last_name => trim $1};
                }
            }
        }
    }

    return $pub;
}

1;
