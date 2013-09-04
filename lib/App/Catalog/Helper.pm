package App::Catalog::Helper::Helpers;

use Catmandu::Sane;
use Catmandu qw(:load export_to_string);
use Catmandu::Util qw(:is :array trim);
use Dancer qw(:syntax vars params request);
use Template;
use Moo;

Catmandu->load;

sub bag {
	state $bag = Catmandu->store->bag;
}

sub config {
	state $config = Catmandu->config;
}

sub authority {
    state $bag = Catmandu->store('authority')->bag;
}

sub getPerson {
	if($_[1] =~ /\d{1,}/){
		$_[0]->authority->get($_[1]);
	} else {
    	$_[0]->authority->select("fullName", qr/$_[1]/i)->to_array;
    }
}

sub add_publication {
	my ($self, $pub) = @_;
	$self->validate($pub);
	bag->add($pub);
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
	my $package;
  	given ($id) {
    	when (/^\d{4}\.\d{4}/) { $package = 'arxiv'}
    	when (/^10\.\d{4}/){ $package = 'doi'}
    	when (/^\d{1,8}$/) { $package = 'pubmed'}
  #  	when (is_isbn($id)) {$package = 'isbn'}
    	default {$package = ''}
  }

  return $package;
}

sub registerDoi {
	my ($self, $pub) = @_;
	#do something ... datacite stuff, Xtian's RESTful API...
}

package App::Catalog::Helper;

my $h = App::Catalog::Helper::Helpers->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook);
use Dancer::Plugin;

register h => sub { $h };

hook before_template => sub {

    $_[0]->{h} = $h;
    
};

register_plugin;

1;