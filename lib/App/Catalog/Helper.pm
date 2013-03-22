package App::Catalog::Helper::Helpers;

use Catmandu::Sane;
use Catmandu qw(:load export_to_string);
use Catmandu::Util qw(:is :array trim);
use Dancer qw(:syntax vars params request);
use Template;
use Moo;

sub bag {
	state $bag = Catmandu->store->bag;
}

sub add_publication {
	my ($self, $pub) = @_;
	$self->validate($pub);
	bag->add($rec);
}

# or clean record?
sub validate {
	my ($self, $pub) = @_;
	# trim
	foreach (keys %$pub) {
		trim $pub->{$_};
	}
	#check ISSN, ISBN

	# kill ugly chars
	return $pub;
}

sub classifyId {
	my ($self, $id) = @_;
	
}


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