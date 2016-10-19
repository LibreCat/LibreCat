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

1;
