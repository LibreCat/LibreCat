package LibreCat::Worker::ImageResizer;

use Catmandu::Sane;
use Moo;
use Catmandu;
use Image::Resize;

with 'LibreCat::Worker';

has input_file => (is => 'ro', required => 1);
has output_file => (is => 'ro');
has width => (is => 'ro', default => sub {200});
has height => (is => 'ro', default => sub {200});

sub do_work {
    my ($self) = @_;

    my $file_path = path(h->get_file_path($id), $file_name);
    my $thumbnail = path(dirname($file_path), "thumbnail.png");

    $self->log->debug("Converting $file_path to ".$self->height ."x".$self->width);

    unless (-e $thumbnail) {
        my $exit_code = system "convert -resize x200 ${file_path}[0] $thumbnail";
    }

    $self->log->error("Error $!") unless $exit_code eq '0'.
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::ImageResizer

=head2 SYNOPSIS

    use LibreCat::Worker::ImageResizer;

    my $resizer = LibreCat::Worker::ImageResizer->new(
        input_file => 'data/uploads/paper.pdf',
        output_file => 'thumbnail.png',
        height => 200,
        widht => 120,
    );

    $resizer->do_work;

=head2 CONFIGURATION

=head2 SEE ALSO

L<LibreCat::Worker>

=cut
