package LibreCat::Layers;

use Catmandu::Sane;
use Catmandu;
use Path::Tiny;
use Moo;
use namespace::clean;

for (qw(paths template_paths public_paths)) {
    has $_ => (is => 'ro', init_arg => undef, default => sub {[]});
}

sub BUILD {
    my ($self, $args) = @_;
    my $paths
        = $args->{paths} || Catmandu->config->{layers} || [Catmandu->root];

    for (reverse @$paths) {
        my $path = path($_);
        $path = $path->absolute(Catmandu->root) if $path->is_relative;
        $path = $path->realpath;

        unshift @{$self->paths}, $path;

        my $template_path = $path->child('templates');
        my $view_path     = $path->child('views');
        my $public_path   = $path->child('public');

        if ($template_path->is_dir) {
            unshift @{$self->template_paths}, $template_path->stringify;
        }

        if ($view_path->is_dir) {
            unshift @{$self->template_paths}, $view_path->stringify;
        }

        if ($public_path->is_dir) {
            unshift @{$self->public_paths}, $public_path->stringify;
        }
    }

}

1;
