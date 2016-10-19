package LibreCat;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use LibreCat::Hook;
use Catmandu;
use namespace::clean;

{
    my $hooks = {};

    sub hook {
        my ($self, $name) = @_;
        $hooks->{$name} ||= do {
            my $args = {
                before_fixes => [],
                after_fixes  => [],
            };

            my $hook = (Catmandu->config->{hooks} || {})->{$name} || {};
            for my $key (qw(before_fixes after_fixes)) {
                my $fixes = $hook->{$key} || [];
                for my $fix (@$fixes) {
                    push @{$args->{$key}}, require_package($fix)->new;
                }
            }

            LibreCat::Hook->new($args);
        };
    }
}

1;

