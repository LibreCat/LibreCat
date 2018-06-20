package Catmandu::Fix::split_author;

=head1 NAME

Catmandu::Fix::split_author - split author strings into subfields "first_name", "last_name" and "full_name"

=head1 SYNOPSIS

   # author => 'Albert Einstein'
   split_author()
   # author => [{
   #     first_name => 'Albert',
   #     last_name => 'Einstein',
   #     full_name => 'Einstein, Albert'
   # }]

   # or
   # author => ["Einstein, Albert", "Monroe, Marylin"]
   # author => [
   # {
   #     first_name => 'Albert',
   #     last_name => 'Einstein',
   #     full_name => 'Einstein, Albert'
   # },
   # {
   #     first_name => 'Marylin',
   #     last_name => 'Monroe',
   #     full_name => 'Monroe, Marylin'
   # },
   #]

=cut

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $pub) = @_;

    foreach my $entity (qw(author editor)) {
        if (my $au = $pub->{$entity}) {
            delete $pub->{$entity};

            $au = (ref $au eq 'ARRAY') ? ($au) : ([$au]);
            foreach my $a (@$au) {
                if ($a =~ /(\w+.*),\s(\w+.*)/) {
                    push @{$pub->{$entity}},
                        {full_name => $a, first_name => $2, last_name => $1};
                }
                elsif ($a =~ /(\w+.*?)\s([A-Z]{1,2})(\sJr|\sSr)*$/) {
                    push @{$pub->{$entity}},
                        {
                        full_name  => "$1, $2",
                        first_name => $2,
                        last_name  => $1
                        };
                }
                elsif ($a =~ /(\w+.*?)\s(\w+.*)$/) {
                    push @{$pub->{$entity}},
                        {
                        full_name  => "$2, $1",
                        first_name => $1,
                        last_name  => $2
                        };
                }
            }
        }
    }

    return $pub;
}

1;
