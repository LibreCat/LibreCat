package Catmandu::Fix::remove_array_field;

use Catmandu::Sane;
use Moo;

has path  => (is => 'ro', required => 1);

around BUILDARGS => sub {
    my ($orig, $class, $path) = @_;
    $orig->($class, path => $path);
};

sub fix {
    my ( $self, $data) = @_;
    my $path = $self->path;
    
    my @paths = split(/\.\*\./, $path);
    my $array_path = $paths[0];
    my $remove_path = $paths[1];
    
    foreach my $rec (@{$data->{$array_path}}){
    	if($rec->{$remove_path}){
    		delete $rec->{$remove_path};
    	}
    }

    $data;
}

1;
