package Dancer::Plugin::Auth::RBAC::Permissions::Catmandu;

use Catmandu::Sane;
use Catmandu qw/store/;
use base qw/Dancer::Plugin::Auth::RBAC::Permissions/;

sub bag {
  my($self,$args)=@_;
  state $bag = store($args->{store})->bag($args->{bag});
}

sub subject_asa {
	my ($self,$options,@arguments) = @_;

  my $accoutnt = $self->bag($options)->get()

}

sub subject_can {
	my ($self, $options, @arguments) = @_;
	
}

1;

=head1 CONFIGURATION

=head3 catmandu.yml

store:
  default:
    package: Catmandu::Store::MongoDB
    options:
      database_name: AuthorityDB

=head3 config.yml  

plugins:
  Auth::RBAC:
    permissions:
      class: Catmandu
   	  options:
        store: default
        bag: users

=cut