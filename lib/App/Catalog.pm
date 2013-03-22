package App::Catalog;

use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';
# the longest module name known to me
use Dancer::Plugin::Auth::RBAC::Credentials::Catmandu; 

# hook before
## login!

use App::Catalog::Import;
use App::Catalog::Helper;


1;
