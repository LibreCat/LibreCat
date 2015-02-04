package Catmandu::Fix::file_json;

use Catmandu::Sane;
use Catmandu::Util qw(:is :data);
use Clone qw(clone);
use Moo;
use JSON;

#has path  => (is => 'ro', required => 1);
#has value => (is => 'ro', required => 1);
#
#around BUILDARGS => sub {
#    my ($orig, $class, $path, $value) = @_;
#    $orig->($class, path => $path, value => $value);
#};

sub fix {
    my ( $self, $pub) = @_;
    
    foreach my $fi (@{$pub->{file}}){
    	$fi->{file_json} = to_json($fi);
    }
    
    $pub;
}

1;

