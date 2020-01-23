use Catmandu::Sane;
use LibreCat -self => -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

my $pkg;

BEGIN {
    $pkg = 'LibreCat::Validation::Error';
    use_ok $pkg;
}

require_ok $pkg;

dies_ok sub {
    $pkg->new();
};

dies_ok sub {
    $pkg->new( code => "error" );
};

dies_ok sub {
    $pkg->new( code => "error", property => "_id" );
};

dies_ok sub {
    $pkg->new( code => "error", property => "_id", field => "_id" );
};

dies_ok sub {
    $pkg->new( code => "error", property => "_id", field => "_id", i18n => ["errors.string.type"] );
};

my $error;

lives_ok sub {
    $error = $pkg->new( code => "error", property => "_id", field => "_id", i18n => ["errors.string.type","array"], validator => "LibreCat::Validator::JSONSchema" );
};

LibreCat->config->{locale}->{en}->{errors}->{string}->{type} = "must be a string, got [_1]";

my $l_message = "must be a string, got array";
is $error->localize(), $l_message, "default lang is en";
is $error, $l_message, "overloaded object returns localized error message in default language";
is $error, $error->to_string(),"overloaded object returns localized error message using to_string";
is $error->localize("en"), $l_message;

done_testing;
