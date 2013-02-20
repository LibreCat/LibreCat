package App::Catalog;
use Catmandu;
use Catmandu::Sane;
use Dancer ':syntax';

our $VERSION = '0.1';

sub store {
  state $store = Catmandu->store;
}

sub bag {
  state $bag = &store->bag;
}

get '/' => sub {
    template 'index';
};

true;
