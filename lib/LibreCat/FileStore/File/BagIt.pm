package LibreCat::FileStore::File::BagIt;

use Moo;

with 'LibreCat::FileStore::File';

1;

__END__

=pod

=head1 NAME

LibreCat::FileStore::File::BagIt - A BagIt implementaiton of a stored file

=head1 SYNOPSIS

    use LibreCat::FileStore::BagIt;

    my $filestore => LibreCat::FileStore::BagIt->new(%options);

    my $file = $filestore->get('1234')->get('myfile.txt');

    my $filename     = $file->key;
    my $content_type = $file->content_type;
    my $size         = $file->size;
    my $created      = $file->created;
    my $modified     = $file->modified;
    my $data         = $file->data;

    my $fh = $file->data->fh;

=head1 SEE ALSO

L<LibreCat::FileStore::File>