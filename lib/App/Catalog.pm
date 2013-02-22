package App::Catalog;
use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';

sub store {
  state $store = Catmandu->store;
}

sub bag {
  state $bag = &store->bag;
}

get '/' => sub {
	my $newRec;
	
	$newRec = params->{newRec} if params->{newRec};
	
	my $hits;
	$hits->{newRec} = $newRec if $newRec;
	
    template 'backend/index', $hits;
};

1;
