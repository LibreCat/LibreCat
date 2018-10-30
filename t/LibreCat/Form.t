use Catmandu::Sane;
use Catmandu -load => [ "t/layer_fh" ];
use Test::More;
use Test::Exception;
use Data::Dumper;

my $pkg = "LibreCat::Form";
use_ok( $pkg );
require_ok( $pkg );

my $loc = "LibreCat::I18N";

use_ok( $loc );
require_ok( $loc );

my $loc_h = "${loc}::_Handle";

my $form;
my $ctx = {
    session => {
        user => "njfranck",
        lang => "nl"
    }
};

dies_ok(sub {

    $pkg->load();

}, "loading form without param id should die" );

dies_ok(sub {

    $pkg->load(
        id => "publication"
    );

}, "loading form without param locale should die" );

lives_ok(sub {

    $pkg->load(
        id => "publication",
        locale => "non_existant_locale"
    );

}, "loading form with invalid locale has fallback to 'en'" );

lives_ok(sub {

    $pkg->load(
        id => "publication",
        locale => "en"
    );

}, "load form with valid id and locale" );

is( $pkg->load( id => "non_existant_form", locale => "en" ), undef, "loading non existant form should return undef" );

dies_ok(sub {

    $pkg->load(
        id => "publication",
        locale => "en",
        ctx => undef
    );

}, "loading form with invalid ctx should die" );

lives_ok(sub {

    $form = $pkg->load(
        id => "publication",
        locale => "en",
        ctx => $ctx
    );

}, "loading form with valid ctx, locale and ctx" );

#Note: lang is set to 'nl' by before_fixes
is_deeply(
    $form->fif,
    +{ first_name => "", name => "", lang => "nl", uid => "njfranck" },
    "initial state of form"
);

$form->is_valid({});

is_deeply(
    $form->fif,
    +{ first_name => "", name => "", lang => "", uid => "" },
    "state after validation"
);

$form->clear();

is_deeply(
    $form->fif,
    +{ first_name => "", name => "", lang => "nl", uid => "njfranck" },
    "initial state of form restored after clear"
);

is( $form->finalize, undef, "final record is undef when not properly validated" );

$form->is_valid({
    first_name => "", name => "Franck", lang => "test", uid => "njfranck"
});

is_deeply(
    $form->last_errors(),
    [
        "First name is required",
        "test is not a valid language"
    ],
    "form.last_errors contains localized errors"
);

$form->is_valid({
    first_name => "Nicolas", name => "Franck", lang => "en", uid => "njfranck"
});

is_deeply(
    $form->finalize,
    +{
        first_name => "Nicolas", name => "Franck", lang => "en", uid => "njfranck",
        status => "new"
    },
    "final record is hash after successfull validation"
);

done_testing;
