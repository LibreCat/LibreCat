package LibreCat::Audit;

use Catmandu::Sane;
use Catmandu;
use Moo;
use Carp qw(confess);
use namespace::clean;

extends "LibreCat::Validator::JSONSchema";

has namespace => (
    is => "ro",
    default => sub { "validator.audit.errors" },
    init_arg => undef
);

has schema => (
    is => "ro",
    lazy => 1,
    default => sub {

        # attribuut 'time' should NOT be added by a user
        # TODO: restrict to these attributes only?
        +{
            '$schema'   => "http://json-schema.org/draft-04/schema#",
            title       => "librecat audit record",
            type        => "object",
            properties  => {
                id => {
                    oneOf => [
                        {
                            type => "string",
                            minLength => 1
                        },
                        {
                            type => "integer",
                            minimum => 0
                        }
                    ]
                },
                bag => {
                    type => "string",
                    minLength => 1
                },
                process => {
                    type => "string",
                    minLength => 1
                },
                action => {
                    type => "string",
                    minLength => 1
                },
                message => {
                    type => "string",
                    minLength => 1
                }
            },
            required => ["id","bag","process","action","message"],
            additionalProperties => 0
        };
    }

);

has bag => (
    is => "ro",
    lazy => 1,
    default => sub {
        Catmandu->store("main")->bag("audit");
    },
    init_arg => undef,
    handles => "Catmandu::Bag"
);

around "add" => sub {

    my ($orig, $self, $rec) = @_;

    return unless $self->is_valid( $rec );

    $rec->{time} = time;

    $orig->($self,$rec);

};

1;

__END__

=pod

=head1 NAME

LibreCat::Audit - model around catmandu bag "audit"

=head1 SYNOPSIS

    use LibreCat::Audit;

    my $audit = LibreCat::Audit->new;

    # add new record to the audit

    my $stored_record = $audit->add({
        id      => 1,
        bag     => "publication",
        process => "librecat publication",
        action  => "add",
        message => "I did it"
    });

    # this package is a subclass of LibreCat::Validator::JSONSchema

    $stored_record  || die( $audit->last_errors() );

    # retrieve all audit records for a specific bag and id

    my $iterator = $audit->select( bag => "publication" )->select( id => 1 );

=head1 DESCRIPTION

This is a L<LibreCat::Validator::JSONSchema> and it expects these, and only these attributes:

    * id:
        * type: string
        * minLength: 1

    * bag:
        * type: string
        * minLength: 1

    * process:
        * type: string
        * minLength: 1

    * action:
        * type: string
        * minLength: 1

    * message:
        * type: string
        * minLength: 1

Because a L<LibreCat::Validator> is also a L<Catmandu::Validator>, methods like C<is_valid> are available.

All records are stored in C<bag> Catmandu->store("main")->("audit")

All methods calls like C<add> or C<each> are proxied to this underlying bag,

available in the method C<bag>.

It is not recommended however to use this bag directly: the method C<add> for example

checks the validity of the input record before adding it to the bag.

=head1 METHODS

=head1 add( $rec ) : $audit_record

    $rec should like this:

        {
            bag     => "name_of_bag",
            id      => "my_id",
            process => "process_that_is_responsible.pl",
            action  => "action within process",
            message => "some random message"
        }

    $rec is validated against the schema (see DESCRIPTION)

    If the validation fails, it return undef. The errors can be retrieved
    by issuing the method C<last_errors>, just like any other L<Catmandu::Validator>

    the current 'time' is added to the record automatically
    before adding it to the underlying bag

    $audit_record should look like the inserted $rec,
    with the attribute 'time' added to it

=head1 SEE ALSO

L<LibreCat::Validator::JSONSchema>

=cut
