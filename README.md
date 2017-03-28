# NAME

LibreCat - Librecat helper functions

# SYNOPSIS

    use LibreCat;

    # Given a 'catmandu' configuration file, like: catmandu.hooks.yml
    # --
    # hooks:
    #   myhook:
    #      before_fixes: [BeforeFix1,BeforeFix2]
    #      after_fixes:  [AfterFix]

    my $hook = LibreCat->hook('eat');

    $hook->fix_before($data);  # BeforeFix1->fix($data) and
                               # BeforeFix2->fix($data) will be executed
    $hook->fix_after($data);   # AfterFix->fix($data) will be executed

# LICENSE AND COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See [http://dev.perl.org/licenses/](http://dev.perl.org/licenses/) for more information.
