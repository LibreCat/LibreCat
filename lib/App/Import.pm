package App::Import;

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default);
use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';

sub identifyId {
	my $id = shift;
	if($id =~ /^10\..*\/.*/){
		return "doi";
	}
	else{
		return "nicht erkannt";
	}
}

"The truth is out there";