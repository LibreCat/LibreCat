package App::Catalog::Controller::File;

use Catmandu::Sane;
use App::Catalog::Helper;
use Exporter qw/import/;

our @EXPORT = qw/new_file edit_file update_file delete_file/;

my $upload_dir = h->config->{upload_dir};

sub _create_id {
    my $bag = h->bag->get('1');
    my $id  = $bag->{"latest"};
    $id++;
    $bag = h->bag->add( { _id => "1", latest => $id } );
    return $id;
}

sub _bagit {
	my $path = shift;
	system "./bagit.py $path";
}

sub new_file {
    return _create_id;
}

# maybe not needed, since all relevant information
# are contained in the publication hash
sub edit_file {}

# this sub should be called from the sub 'update_publication',
# if publication has a file attached
sub update_file {
	my $pub = shift;
	my $dir = $upload_dir ."/$pub->{_id}";
	mkdir $dir unless -e $dir || croak "Can't create directory";

}

# this sub should be called from the sub 'delete_publication',
# if publication has a file attached
sub delete_file {
    my $pub = shift;
    my $file = $upload_dir ."/$pub->{_id}";
    unlink($file);
}

1;
