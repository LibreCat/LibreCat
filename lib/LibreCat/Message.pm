package LibreCat::Message;

use Catmandu::Sane;
use Catmandu;
use Moo;
use namespace::clean;

extends "LibreCat::Validator::JSONSchema";

has namespace => (
    is       => "ro",
    default  => sub {"validator.message.errors"},
    init_arg => undef
);

has schema => (
    is      => "ro",
    lazy    => 1,
    default => sub {

        # attribuut 'time' should NOT be added by a user
        # TODO: restrict to these attributes only?
        +{
            # '$schema'  => "http://json-schema.org/draft-04/schema#",
            # title      => "librecat message record",
            # type       => "object",
            # properties => {
            #     record_id => {
            #         oneOf => [
            #             {type => "string",  minLength => 1},
            #             {type => "integer", minimum   => 0}
            #         ]
            #     },
            #     user_id => {
            #         oneOf => [
            #             {type => "string",  minLength => 1},
            #             {type => "integer", minimum   => 0}
            #         ]
            #     },
            #     message => {type => "string", minLength => 2}
            # },
            # required             => ["record_id", "user_id", "message"],
            # additionalProperties => 0
        };
    }

);

has bag => (
    is      => "ro",
    lazy    => 1,
    default => sub {
        Catmandu->store("main")->bag("message");
    },
    init_arg => undef,
    handles  => "Catmandu::Bag"
);

around "add" => sub {

    my ($orig, $self, $rec) = @_;

    return unless $self->is_valid($rec);

    $rec->{time} = time;

    $orig->($self, $rec);

};

1;

__END__

=pod

=head1 NAME

LibreCat::Message - model around catmandu bag "message"

=head1 SYNOPSIS

    use LibreCat::Message;

    my $msg = LibreCat::Message->new;

    # add new record to the message bag

    my $stored_record = msg->add({
        record_id => 1,
        user_id   => 1234,
        message   => "I did it"
    });

    # this package is a subclass of LibreCat::Validator::JSONSchema

    $stored_record  || die( $audit->last_errors() );

    # retrieve all messages records for a specific bag and record_id

    my $iterator = $msg->select( record_id => 1 );

=head1 DESCRIPTION

This is a L<LibreCat::Validator::JSONSchema> and it expects these, and only these attributes:

    * record_id:
        * oneOf:
            * type => "string",
              minLength => 1
            * type => "integer",
              minimum => 0

    * user_id:
        * oneOf:
            * type => "string",
              minLength => 1
            * type => "integer",
              minimum => 0

    * message:
        * type: string
        * minLength: 2

Because a L<LibreCat::Validator> is also a L<Catmandu::Validator>, methods like C<is_valid> are available.

All records are stored in C<bag> Catmandu->store("main")->("message")

All methods calls like C<add> or C<each> are proxied to this underlying bag,

available in the method C<bag>.

It is not recommended however to use this bag directly: the method C<add> for example

checks the validity of the input record before adding it to the bag.

=head1 METHODS

=head1 add( $rec ) : $message_record

    $rec should like this:

        {
            record_id => "my_id",
            user _id => 1234,
            message => "some random message"
        }

    $rec is validated against the schema (see DESCRIPTION).

    If the validation fails, it returns undef. The errors can be retrieved
    by issuing the method C<last_errors>, just like any other L<Catmandu::Validator>.

    The current 'time' is added to the record automatically
    before adding it to the underlying bag.

    $message_record should look like the inserted $rec,
    with the attribute 'time' added to it.

=head1 SEE ALSO

L<LibreCat::Validator::JSONSchema>

=cut
