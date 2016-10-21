package LibreCat;

use Catmandu::Sane;
use Catmandu::Util qw(require_package);
use Catmandu;
use LibreCat::Hook;
use LibreCat::User;
use namespace::clean;

sub user {
    state $user = do {
        my $config = Catmandu->config->{user};
        LibreCat::User->new($config);
    };
}

sub auth {
    state $auth = do {
        my $pkg = require_package(Catmandu->config->{authentication}->{package});
        $pkg->new(Catmandu->config->{authentication}->{options} // {});
    };
}

{
    my $hook_ns = 'LibreCat::Hook';
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
                    push @{$args->{$key}}, require_package($fix, $hook_ns)->new;
                }
            }

            LibreCat::Hook->new($args);
        };
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat - Librecat helper functions

=head1 SYNOPSIS

    use LibreCat;

    # given a configuration file like hooks.yml:
    # --
    # hooks:
    #   myhook:
    #      before_fixes: [BeforeFix1,BeforeFix2]
    #      after_fixes:  [AfterFix]

    my $hook = LibreCat->hook('eat');

    $hook->fix_before($data);  # BeforeFix1->fix($data) and
                               # BeforeFix2->fix($data) will be executed
    # do stuff ...
    $hook->fix_after($data);   # AfterFix->fix($data) will be executed

    # more concise:
    $hook->fix_around($data, sub {
        # do stuff ...
    });

=cut
