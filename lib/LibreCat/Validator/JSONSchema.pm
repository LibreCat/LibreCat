package LibreCat::Validator::JSONSchema;

use Catmandu::Sane;
use Catmandu::Util qw(is_natural :check);
use Moo;
use LibreCat::Validation::Error;
use Catmandu::Validator::JSONSchema;
use namespace::clean;

with 'LibreCat::Validator';

has schema => (
    is => "ro",
    isa => sub { check_hash_ref($_[0]); },
    required => 1
);

has schema_validator => (
    is => "lazy",
    init_arg => undef
);

sub _build_schema_validator {

    Catmandu::Validator::JSONSchema->new(
        schema => $_[0]->schema()
    );

}

sub _build_whitelist {
    my ($self) = @_;
    my $properties = $self->schema->{properties} // {};
    [keys %$properties];
}

sub _t_error {

    my($self,$error) = @_;

    my $prop = $error->{property};

    #/file/0/access_level => file.0.access_level
    $prop    =~ s/^\///o;
    $prop    = join( ".",split( "/",$prop ) );
    $prop    = "." if $prop eq "";

    #/file/0/access_level => file.access_level
    my $f    = join( ".",grep { !is_natural($_) } split( /\./,$prop ) );
    $f       = "." if $f eq "";

    my @details = @{ $error->{details} };

    my $d_key1  = shift(@details);
    my $d_key2  = shift(@details);
    my @d_args  = @details;

    #code
    my $code = "${d_key1}.${d_key2}";

    #i18n
    my $i18n = [ $self->namespace() . "." . $code, $f, @d_args ];

    LibreCat::Validation::Error->new(
        #error code
        code      => $code,
        #list of arguments for localisation
        i18n      => $i18n,
        #json path to the cause of the error
        property  => $prop,
        #shorter field name
        field     => $f,
        validator => ref($self)
    );
}

sub validate_data {

    my($self, $hash)=@_;

    my $errors = undef;

    unless(

        $self->schema_validator->is_valid( $hash )

    ){

        $errors = [
            map { $self->_t_error($_); } @{ $self->schema_validator->last_errors() }
        ];

    }

    $errors;

}

1;

__END__

=pod

=head1 NAME

LibreCat::Validator::JSONSchema - a JSONSchema validator

=head1 SYNOPSIS

    package MyPackage;

    use LibreCat::Validator::JSONSchema;
    use LibreCat::App::Helper;

    my $publication_validator =
        LibreCat::Validator::JSONSchema->new(schema => h->config->{schemas}{publication});

    if ($publication_validator->is_valid($rec)) {
        # ...
    }

=head1 SEE ALSO

L<LibreCat>, L<Librecat::Validator>, L<Catmandu::Validator>,
L<Catmandu::Validator::JSONSchema>, L<config/schemas.yml>

=cut
