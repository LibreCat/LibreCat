package LibreCat::Rule::affiliated_with;

use Catmandu::Sane;
use Catmandu::Util qw(array_any);
use Moo;
use namespace::clean;

with 'LibreCat::Rule';

sub test {
    my ($self, $subject, $object, $param) = @_;

    my $dep = $object->{department};
    $dep && ($dep->{_id} eq $param || ($dep->{tree} && array_any($dep->{tree}, sub { $_[0]->{_id} eq $param })));
}

1;
