package LibreCat::Validator::JSONSchema;

use Catmandu::Sane;
use Catmandu::Util qw(is_natural);
use Moo;
use namespace::clean;

extends 'Catmandu::Validator::JSONSchema';

with 'LibreCat::Validator';

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
    my $i18n = [ $self->namespace() . "." . $code, @d_args ];

    +{
        #error code
        code      => $code,
        #list of arguments for localisation
        i18n      => $i18n,
        #json path to the cause of the error
        property  => $prop,
        #shorter field name
        field     => $f,
        #name of validator
        validator => "jsonschema",
        message   => $error->{message}
    };
}

around last_errors => sub {
    my $orig   = shift;
    my $self   = shift;
    my $errors = $orig->($self,@_) // return;
    [
      map { $self->_t_error($_) } @$errors
    ];
};

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
