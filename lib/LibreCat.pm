package LibreCat;

use Catmandu::Sane;
use Catmandu;
use LibreCat::User;

sub user {
    state $user = do {
        my $config = Catmandu->config->{user};
        LibreCat::User->new($config);
    };
}

1;

