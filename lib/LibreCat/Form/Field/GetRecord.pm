package LibreCat::Form::Field::GetRecord;
use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(:is);
use HTML::FormHandler::Moose;

extends "HTML::FormHandler::Field::Text";

has "store_name" => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { "default"; },
    init_arg => "store"
);

has "bag_name" => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { "data"; },
    init_arg => "bag"
);

has _bag => (
    is => "ro",
    lazy => 1,
    builder => "_build_bag"
);

sub _build_bag {

    Catmandu->store( $_[0]->store_name )->bag( $_[0]->bag_name );

}

our $class_messages = {
    record_not_found => "Record [_1] not found",
};

sub get_class_messages {

    my $self = $_[0];

    return {
        %{ $self->next::method },
        %$class_messages,
    };

}

sub validate {

    my $self = $_[0];

    $self->add_error(
        $self->get_message( "record_not_found" ),$self->value
    ) unless $self->_bag->get($self->value);

}

__PACKAGE__->meta->make_immutable;
use namespace::autoclean;

1;
