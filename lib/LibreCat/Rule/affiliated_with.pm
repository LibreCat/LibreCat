package LibreCat::Rule::affiliated_with;

use Catmandu::Sane;
use Catmandu::Util qw(array_any);
use Moo;
use namespace::clean;

with 'LibreCat::Rule';

has key => (is => 'lazy');

sub _build_key {
    my ($self) = @_;
    $self->args->[0] // '_id';
}

sub test {
    my ($self, $subject, $object, $params) = @_;
    my $key = $self->key;
    my $id  = $params->{$key} // Catmandu::Error->throw("Missing role parameter '$key'");
    my $dep = $object->{department};
    $dep
        && (
        $dep->{_id} eq $id
        || ($dep->{tree}
            && array_any($dep->{tree}, sub {$_[0]->{_id} eq $id}))
        );
}

1;
