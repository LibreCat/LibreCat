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
#has image_resizer => (is => 'lazy');

sub _build_image_resizer {
    my ($self) = @_;

    my $resizer = Image::Resizer->new($self->input_file);

}

sub do_work {
    my ($self) = @_;

    my $file_path = path(h->get_file_path($id), $file_name);
    my $thumbnail = path(dirname($file_path), "thumbnail.png");
    unless (-e $thumbnail) {
        system "convert -resize x200 ${file_path}[0] $thumbnail";
    }

#    my $gd = $self->image_resizer->resize($self->width, $self->height);


}

1;
