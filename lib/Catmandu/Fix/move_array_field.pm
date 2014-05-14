package Catmandu::Fix::move_array_field;

use Catmandu::Sane;
use Moo;

has old_path => (is => 'ro', required => 1);
has new_path => (is => 'ro', required => 1);

around BUILDARGS => sub {
    my ($orig, $class, $old_path, $new_path) = @_;
    $orig->($class, old_path => $old_path, new_path => $new_path);
};

sub fix {
    my ( $self, $data) = @_;
    my $old_path = $self->old_path;
    my $new_path = $self->new_path;
    
    my @old_paths = split(/\.\*\./, $old_path);
    my $old_array_path = $old_paths[0];
    my $old_move_path = $old_paths[1];
    
    my @new_paths = split(/\.\*\./, $new_path);
    #my $new_array_path = $new_paths[0];
    my $new_move_path = $new_paths[1];
    
    foreach my $rec (@{$data->{$old_array_path}}){
    	if($rec->{$old_move_path}){
    		$rec->{$new_move_path} = $rec->{$old_move_path};
    		delete $rec->{$old_move_path};
    	}
    }

    $data;
}

1;
