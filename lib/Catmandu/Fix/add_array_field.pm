package Catmandu::Fix::add_array_field;

use Catmandu::Sane;
use Catmandu::Util qw(:is :data);
use Clone qw(clone);
use Moo;

has path  => (is => 'ro', required => 1);
has value => (is => 'ro', required => 1);

around BUILDARGS => sub {
    my ($orig, $class, $path, $value) = @_;
    $orig->($class, path => $path, value => $value);
};

sub fix {
    my ( $self, $data) = @_;
    my $path = $self->path;
    my $value = $self->value;
    
    my @paths = split(/\.\*\./, $path);
    my $array_path = $paths[0];
    my $key = $paths[1];
    
    foreach my $rec (@{$data->{$array_path}}){
    	$rec->{$key} = $value;
    }

    $data;
}

1;

