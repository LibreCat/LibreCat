package LibreCat::Hook;

use Catmandu::Sane;
use Moo;

has name         => (is => 'ro');
has before_fixes => (is => 'ro', default => sub {[]});
has default_before_fixes => (is => 'ro', default => sub {[]});
has default_after_fixes  => (is => 'ro', default => sub {[]});
has after_fixes  => (is => 'ro', default => sub {[]});

sub fix_before {
    my ($self, $data) = @_;
    $_->fix($data) for @{$self->before_fixes};
    $_->fix($data) for @{$self->default_before_fixes};
    $data;
}

sub fix_after {
    my ($self, $data) = @_;
    $_->fix($data) for @{$self->default_after_fixes};
    $_->fix($data) for @{$self->after_fixes};
    $data;
}

sub fix_around {
    my ($self, $data, $sub) = @_;
    $self->fix_before($data);
    $data = $sub->($data) if defined $sub;
    $self->fix_after($data);
}

1;

__END__

=head1 NAME

LibreCat::Hook - create call back functions to be executed at important LibreCat events

=head1 SYNOPSIS

    ## In your configuration files
    # config/hooks.yml

    hooks:
      my-event:
        before_fixes:
          - foo
          - bar
        after_fixes:
          - acme

    ## In your perl code;

    # test.pl:
    use LibreCat load => (layer_paths => [qw(/opt/my-layer)]);

    my $hook = LibreCat->hook('my-event');

    # This will execute: LibreCat::Hook::foo , LibreCat::Hook::bar
    $hook->fix_before({ param1 => ... , param2 => ... } );

    # do some important code...

    # This will execute: LibreCat::Hook::acme
    $hook->fix_after({ param1 => ... , param2 => ... });

    ## A more elegant way to do the above is to use a fix_around method
    # test.pl:
    use LibreCat load => (layer_paths => [qw(/opt/my-layer)]);

    my $hook = LibreCat->hook('my-event');
    my $data = {test => 'me'};

    $hook->fix_around($data, sub {
        # do some stuff here with $data,
        # e.g. add $data to a store
    });

=head1 DESCRIPTION

Hooks are ways to extend a LibreCat application. At important points in the
application after, before and around named hooks can be defined. Using a configuration
file arbitrary code can be executed at those places.

In the example above, in the LibreCat code a 'my-event' hook is defined and
fix_before and fix_after method are called before and after some particular event.

When you want to run arbitrary code before or after this event, then a 'hooks'
configuration file needs to be created which specifies which code should be executed.

In the catmandu.hooks.yml configuration file for example a 'foo' hook is defined.
This is a Perl module in the 'LibreCat::Hook::foo' namespace which implements a
'fix' method:

    package LibreCat::Hook::foo;

    use Moo;

    sub fix {
        my ($self, $data) = @_;

        # .. your code ...
        return $data;
    }

    1;

The fix gets as input all the parameters specified in the main LibreCat application
'test.pl'.

Look at the C<config/hooks.yml> file for example hooks that are defined for the
LibreCat web application.

=head1 WARNING

DO NOT USE the keys B<default_before_fixes> and B<default_after_fixes> in your local layers file.

=cut
