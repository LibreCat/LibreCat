package LibreCat;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(require_package);
use LibreCat::User;
use namespace::clean;

sub user {
    state $user = do {
        my $config = Catmandu->config->{user};
        LibreCat::User->new($config);
    };
}

sub auth {
    state $auth = do {
        my $pkg = require_package(Catmandu->config->{authentication}->{package});
        $pkg->new(Catmandu->config->{authentication}->{options} // {});
    };
}

1;

