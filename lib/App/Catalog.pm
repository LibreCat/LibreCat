package App::Catalog;

use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Plugin::Auth::RBAC::Credentials::Catmandu; # the longest module name known to me

# hook before
## login!

use App::Catalog::Import;
use App::Catalog::Helper;


1;
