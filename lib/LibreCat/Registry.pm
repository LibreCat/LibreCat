package LibreCat::Registry;

use Catmandu::Sane;
use Moo;
use Catmandu;
use Catmandu::Util qw(:check join_path use_lib require_package);
use File::Path qw(make_path);
use Plack::App::File;
use Plack::App::Cascade;
use Plack::Util;
use Config::Onion;

foreach (qw(component_dirs lib_dirs test_dirs config_dirs template_dirs public_dirs psgi_files)) {
    has $_ => (is => 'ro', init_arg => undef, default => sub { [] });
}

foreach (qw(psgi_app config)) {
    has $_ => (is => 'rwp', init_arg => undef);
}

sub BUILD {
    my ($self, $args) = @_;

    my @components = (Catmandu->root);
    if ($args->{components}) {
        push @components, @{$args->{components}};
    }

    my $component_dir = join_path(Catmandu->root, 'components');
    my @psgi_apps;

    for my $dir (reverse @components) {
        if (ref $dir) {
            check_string(my $url = $dir->{url});
            check_maybe_string($dir = $dir->{as});
            state $git = require_package('Git::Repository');
            unless ($dir) {
                ($dir) = $url =~ /([^\/]+)$/;
                $dir =~ s/\.git$//;
            }

            make_path($component_dir);
            $dir = join_path($component_dir, $dir);
            unless (-d $dir) {
                $git->run('clone', $url, $dir);
            }
        } else {
            my ($volume, $directories) = File::Spec->splitpath($dir);
            if (length $volume || length $directories) {
                $dir = File::Spec->rel2abs($dir, Catmandu->root);
            } else {
                $dir = join_path($component_dir, $dir);
            }
            unless (-d $dir) {
                confess "component directory $dir doesn't exist";
            }
        }

        unshift @{$self->component_dirs}, $dir;

        my $lib_dir = join_path($dir, 'lib');
        my $test_dir = join_path($dir, 't');
        my $config_dir = join_path($dir, 'config');
        my $template_dir = join_path($dir, 'templates');
        my $psgi_dir = join_path($dir, 'psgi');
        my $public_dir = join_path($dir, 'public');

        if (-d -r $lib_dir) {
            unshift @{$self->lib_dirs}, $lib_dir;
            use_lib $lib_dir;
        }

        if (-d -r $config_dir) {
            unshift @{$self->config_dirs}, $config_dir;
        }

        if (-d -r $test_dir) {
            unshift @{$self->test_dirs}, $test_dir;
        }

        if (-d -r $template_dir) {
            unshift @{$self->template_dirs}, $template_dir;
        }

        if (-d -r $psgi_dir) {
            opendir(my $dh, $psgi_dir);
            for my $file (grep /\.(pl|psgi)$/, readdir($dh)) {
                $file = join_path($psgi_dir, $file);
                if (-f -r $file) {
                    unshift @{$self->psgi_files}, $file;
                    unshift @psgi_apps, Plack::Util::load_psgi($file);
                }
            }
            closedir($dh);
        }

        if (-d -r $public_dir) {
            unshift @{$self->public_dirs}, $public_dir;
            unshift @psgi_apps, Plack::App::File->new(root => $public_dir);
        }
    }

    if (@psgi_apps) {
        $self->_set_psgi_app(@psgi_apps > 1
            ? Plack::App::Cascade->new(apps => \@psgi_apps)->to_app
            : $psgi_apps[0]
        );
    }

    my $conf = Config::Onion->new;
    $conf->load_glob(map { join_path($_, '*') } reverse @{$self->config_dirs});
    $self->_set_config($conf->get);
}

1;
