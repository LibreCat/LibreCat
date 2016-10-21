package LibreCat::Hook;

use Catmandu::Sane;
use Moo;

has before_fixes => (is => 'ro', default => sub{[]});
has after_fixes  => (is => 'ro', default => sub{[]});

sub fix_before {
    my ($self, $data) = @_;
    $_->fix($data) for @{$self->before_fixes};
    $data;
}

sub fix_after {
    my ($self, $data) = @_;
    $_->fix($data) for @{$self->after_fixes};
    $data;
}

sub fix_around {
    my ($self, $data, $sub) = @_;
    $self->fix_before($data);
    $data = $sub->($data);
    $self->fix_after($data);
}

1;
