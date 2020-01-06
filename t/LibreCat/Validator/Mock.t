use Catmandu::Sane;
use LibreCat -self => -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use warnings FATAL => 'all';

{

    package LibreCat::Validator::Mock;
    use Moo;
    extends "LibreCat::Validator::JSONSchema";

    around validate_data => sub {
        my ($orig, $self,@args) = @_;
        my $errors = $orig->($self,@args);

        my $record = shift( @args );

        if( exists( $record->{user_id} ) ){

            my $user = LibreCat->instance->model("user")->get( $record->{user_id} );

            unless( $user ) {

                push @$errors, LibreCat::Validation::Error->new(
                    code      => "user.not_found",
                    i18n      => [
                        "validator.mock.errors.user.not_found","user_id",$record->{user_id}
                    ],
                    property  => "user_id",
                    field     => "user_id",
                    validator => ref($self)
                );

            }

        }


        $errors;
    };

}

LibreCat->config->{locale}{en}{validator}{mock}{errors}{user}{not_found} = "user with identifier [_2] could not be found";
LibreCat->config->{models}{publication}{validator} = {
    package => "LibreCat::Validator::Mock",
    options => {
        schema => "publication"
    }
};

my $validator;

lives_ok(sub{

    $validator = LibreCat->instance->model("publication")->validator();

});

my $record = {
    _id => "a",
    title => "a",
    type  => "book",
    status => "new"
};

ok $validator->is_valid($record);

$record->{user_id} = "this_user_should_not_exist";

ok ! $validator->is_valid($record);

is $validator->last_errors()->[0]->localize("en"), "user with identifier this_user_should_not_exist could not be found";

done_testing;
