package LibreCat::Worker::FileUploader;

use Moo;
use Catmandu::Util;
use IO::File;
use namespace::clean;

with 'LibreCat::Worker';

has package    => (is => 'ro' , required => 1);
has options    => (is => 'ro');
has file_store => (is => 'lazy');

sub _build_file_store {
    my ($self) = @_;

    my $file_store = $self->package;
    my $file_opts  = $self->options // {};

    my $pkg = Catmandu::Util::require_package($file_store,'LibreCat::FileStore');
    $pkg->new(%$file_opts);
}

# TODO: Need to change request and session to the actual paramters to use
sub do_work {
    my ($self, $request, $session) = @_;

    my $key = $request->params->{'key'};

    return -1 unless defined $key && $key =~ /^\d{9}$/;

    my $container = $self->file_store->get($key);

    unless ($container) {
        $container = $self->file_store->add($key);
    }

    if ($container) {
        my $file    = $request->upload('file');

        unless ($file) {
            return -1;
        }

        $container->add($file->{filename}, IO::File->new($file->{tempname}));

        $container->commit;

        return 1;
    }
    else {
        return -1;
    }
}

1;

__END__

__END__

=pod

=head1 NAME

LibreCat::Worker::FileUploader - a worker for uploading files into the repostitory

=head2 SYNOPSIS

    use LibreCat::Worker::FileUploader;

    my $uploader = LibreCat::Worker::FileUploader->new(
                    package => 'Simple', 
                    options => {
                        root => '/data2/librecat/file_uploads'
                    });

    $uploader->do_work(<Dancer::Request>,<Dancer::Session>);

=head2 CONFIGURATION

=over

=item package

Required. The LibreCat::FileStore implementation to use.

=item options

Optional. Any LibreCat::FileStore options to use.

=back

=head2 SEE ALSO

L<LibreCat::Worker>

=cut
