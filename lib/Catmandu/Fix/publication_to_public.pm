package Catmandu::Fix::publication_to_public;

use Catmandu::Sane;
use Moo;
use Dancer qw(:syntax config);

sub fix {
  my ( $self, $rec ) = @_;

  foreach my $r ( @{ $rec->{records} } ) {
    my $pub = $r->{record};

    if ( $pub->{author} ) {
      foreach my $auth ( @{ $pub->{author} } ) {
        delete $auth->{luLdapId};
        delete $auth->{oId};
        delete $auth->{type};
        delete $auth->{citationStyle};
        delete $auth->{sortDirection};
        delete $auth->{email};
        delete $auth->{searchName};
      }
    }

    if ( $pub->{editor} ) {
      foreach my $ed ( @{ $pub->{editor} } ) {
        delete $ed->{luLdapId};
        delete $ed->{oId};
        delete $ed->{type};
        delete $ed->{citationStyle};
        delete $ed->{sortDirection};
        delete $ed->{email};
        delete $ed->{searchName};
      }
    }

    if ( $pub->{language} ) {
      $pub->{language} = $pub->{language}->{name};
    }

    foreach (
      qw(creator promoter message oId file type
      conference subject schema intvolume uploadDirectory type)
      )
    {
      delete $pub->{$_};
    }

    if ( $pub->{project} ) {
      foreach my $p ( @{ $pub->{project} } ) {
        delete $p->{oId};
        delete $p->{type};
        delete $p->{pspElement};
        $p->{name} = $p->{name}->[0]->{text};
      }
    }

    if ( $pub->{department} ) {
      foreach my $d ( @{ $pub->{department} } ) {
        delete $d->{oId};
        delete $d->{type};
        delete $d->{allDepartments};
        $d->{name} = $d->{name}->[0]->{text};
      }
    }

    if ( $pub->{metrics} ) {
      delete $pub->{metrics}->{timesCited};
      delete $pub->{metrics}->{timesCitedHistory};
    }

  }
  $rec;
}

1;
