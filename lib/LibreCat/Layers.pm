package LibreCat::Layers;

use Catmandu::Sane;
use Catmandu::Util qw(use_lib);
use Catmandu;
use Path::Tiny;
use Moo;
use namespace::clean;

for (qw(paths
        template_paths)) {
    has $_ => (is => 'ro', init_arg => undef, default => sub { [] });
}

sub BUILD {
    my ($self, $args) = @_;
    my $paths = $args->{paths} || Catmandu->config->{layers} || [];

    unshift @$paths, Catmandu->root;

    for (reverse @$paths) {
        my $path = path($_);
        $path = $path->absolute(Catmandu->root) if $path->is_relative;
        $path = $path->realpath;

        unshift @{$self->paths}, $path;

        my $lib_path = $path->child('lib');
        my $template_path = $path->child('templates');

        if ($lib_path->is_dir) {
            unshift @{$self->lib_paths}, $lib_path;
        }

        if ($template_path->is_dir) {
            unshift @{$self->template_paths}, $template_path;
        }
    }

}

sub load {
    my ($self) = @_;

    use_lib @{$self->lib_paths};

    $self;
}

1;
