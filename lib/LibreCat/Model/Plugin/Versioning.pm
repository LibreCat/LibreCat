package LibreCat::Model::Plugin::Versioning;

use Catmandu::Sane;
use Moo::Role;

sub get_history              {shift->bag->get_history(@_)}
sub get_version              {shift->bag->get_version(@_)}
sub restore_version          {shift->bag->restore_version(@_)}
sub get_previous_version     {shift->bag->get_previous_version(@_)}
sub restore_previous_version {shift->bag->restore_previous_version(@_)}

1;

