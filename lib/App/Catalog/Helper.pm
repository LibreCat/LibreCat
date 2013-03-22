package App::Catalog::Helper::Helpers;

use Catmandu::Sane;
use Catmandu qw(:load export_to_string);
use Catmandu::Util qw(:is :array);
use Dancer qw(:syntax vars params request);
use Template;
use Moo;



package PUBSearch::Helper;

my $h = PUBSearch::Helper::Helpers->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook);
use Dancer::Plugin;

register h => sub { $h };

hook before_template => sub {

    $_[0]->{h} = $h;
    
};

register_plugin;

"This is truth";