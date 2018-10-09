package LibreCat::Form;
use Catmandu::Sane;
use Catmandu::Util qw(:is :check);
use Catmandu;
use Catmandu::Error;
use LibreCat::I18N;
use Clone qw();
use Moo;
use HTML::FormHandler;
use Catmandu::Fix;

with "Catmandu::Pluggable", "Catmandu::Validator", "LibreCat::Logger";

#creates init_object
has before_fix => (
    is => "ro",
    default => sub { []; },
    required => 0,
    coerce => sub {
        Catmandu::Fix->new( fixes => $_[0] );
    },
    init_arg => "before_fixes"
);

#for fixed fif ( which is not the same as "fif" )
has after_fix => (
    is => "ro",
    default => sub { []; },
    required => 0,
    coerce => sub {
        Catmandu::Fix->new( fixes => $_[0] );
    },
    init_arg => "after_fixes"
);

has field_list => (
    is => "ro",
    isa => sub { check_array_ref($_[0]); },
    default => sub { []; },
    required => 1,
    init_arg => "fields"
);

has ctx => (
    is => "ro",
    isa => sub { check_hash_ref($_[0]); },
    required => 0,
    default => sub { +{}; }
);

has init_object => (
    is => "lazy",
    isa => sub { check_hash_ref($_[0]); },
    init_arg => undef
);

has language_handle => ( is => "ro" );

has hfh => ( is => "lazy", init_arg => undef );

sub _build_init_object {

    my $self = $_[0];

    my $o = +{};

    for my $field( @{ $self->field_list() } ){

        next unless exists( $field->{default} );
        $o->{ $field->{name} } = $field->{default};

    }

    $o->{_ctx} = $self->ctx();

    $o = $self->before_fix()->fix($o);

    delete $o->{_ctx};

    $o;

}

sub _build_hfh {
    my $self = $_[0];
    HTML::FormHandler->new(
        field_list => $self->field_list(),
        language_handle => $self->language_handle(),
        init_object => $self->init_object(),
        ctx => $self->ctx()
    );
}

sub validate_data {

    my( $self, $data ) = @_;

    $self->clear();

    $self->hfh()->process( params => $data, posted => 1, init_object => $self->init_object() );

    my @errors = $self->hfh()->errors();

    $self->{_validation_has_run} = 1;

    #"an array" is interpreted as invalid
    scalar(@errors) ? \@errors : undef;

}

sub fif {

    #Note: hfh always returns copy of hash
    $_[0]->hfh()->fif();

}

#TODO: method "validate" returns filtered list of validated records.
#      but these are the non finalized records.
sub finalize {

    my $self = $_[0];

    return unless $self->{_validation_has_run};

    my $fif = Clone::clone( $self->fif() );

    $fif->{_ctx} = $self->ctx();

    $fif = $self->after_fix()->fix( $fif );

    delete $fif->{_ctx};

    $fif;

}

sub clear {

    my $self = $_[0];

    delete $self->{_validation_has_run};

    #form->clear removes the result and set all fields to 'inactive'. This is safer
    #process calls clear afterwards
    $self->hfh()->process(
        params => {},
        posted => 0,
        init_object => $self->init_object(),
        ctx => $self->ctx()
    );

};

sub fields {

    $_[0]->hfh()->sorted_fields();

}

sub field {

    my( $self, @args ) = @_;
    $self->hfh()->field( @args );

}

sub errors {

    [ $_[0]->hfh()->errors() ];

}

sub load {

    my ( $class, %opts ) = @_;

    my $id = delete $opts{id};
    my $locale = delete $opts{locale};

    Catmandu::BadArg->throw( "no id given" ) unless is_string( $id );
    Catmandu::BadArg->throw( "no locale given" ) unless is_string( $locale );
    Catmandu::BadArg->throw( "ctx should be hash" )
        if exists( $opts{ctx} ) && !is_hash_ref( $opts{ctx} );

    return unless exists( Catmandu->config->{form_handlers}->{ $id } );

    my $config = Catmandu->config->{form_handlers}->{ $id };

    Catmandu::Error->throw( "configuration for form_handler $id should be hash" )
        unless is_hash_ref( $config );

    Catmandu::Error->throw( "no fields configured for form_handler $id" )
        unless is_array_ref( $config->{fields} );

    my %args = (
        fields => Clone::clone( $config->{fields} ),
    );

    $args{ctx} = $opts{ctx} if exists( $opts{ctx} );

    if( exists( $config->{before_fixes} ) ){

        Catmandu::Error->throw( "before_fixes of form_handler $id should be array" )
            unless is_array_ref( $config->{before_fixes} );

        $args{before_fixes} = $config->{before_fixes};

    }

    if( exists( $config->{after_fixes} ) ){

        Catmandu::Error->throw( "after_fixes of form_handler $id should be array" )
            unless is_array_ref( $config->{after_fixes} );

        $args{after_fixes} = $config->{after_fixes};

    }

    state $language_handles = {};
    $language_handles->{$locale} ||= LibreCat::I18N::_Handle->get_handle( $locale );

    Catmandu::Error->throw( "unable to find locale $locale" )
        unless $language_handles->{$locale};

    $args{language_handle} = $language_handles->{$locale};

    $class->new( %args );

}

=head1 NAME

LibreCat::Form - class to create and validate html form parameters

=head1 Configuration I18N

    locale:
      en:
        fh_user:
          fields:
            name:
              label: "Name (*)"
            email:
              label: "Email (*)"
          errors:
            name:
              required: "Name is required"
            email:
              required: "Email is required"
              email_format: "'[_1]' is not a valid email address"

=head1 Configuration forms

    form_handlers:
      fh_user:
        before_fixes: [ "fh_user_show.fix" ]
        after_fixes: [ "fh_user_finalize.fix" ]
        fields:
          - name: "name"
            label: "fh_user.fields.name.label"
            type: "Text"
            required: 1
            messages:
              required: "fh_user.errors.name.required"
          - name: "email"
            label: "fh_user.fields.email.label"
            type: Email
            required: 1
            messages:
              required: "fh_user.errors.email.required"
              email_format: "fh_user.errors.email.email_format"

=head1 Synopsis

#load form

my $form = LibreCat::Form->load(
    id => "fh_user",
    locale => "en",
    ctx => {
        session => {
            user => "njfranck"
        }
    }
);

#'filled-in-form' or simply 'fif'. This is the initial state.

#returns a hash reference

my $initial_fif = $form->fif();

#validate parameters

#LibreCat::Form is a Catmandu::Validator!

$form->is_valid({
    name => "Nicolas Franck",
    email => "nicolas franck at ugent be"
});

#get array reference of localized errors: [ "'nicolas franck at ugent be' is not a valid email address" ]

my $errors = $form->last_errors();

#get array reference of localized errors for one field

my $email_errors = $form->field("email")->errors();

#finalize: convert parameters into valid record to store

#returns undef when form is not valid

my $record = $form->finalize();

#clear form to initial state

#called automatically before every validation

$form->clear();

#validation ok now
$form->is_valid({
    name => "Nicolas Franck",
    email => "nicolas.franck@ugent.be"
});

$record = $form->finalize();

=head1 METHODS

=over

=item load( id => "form-id", locale => "language" [, ctx => $ctx ] )

Load L<LibreCat::Form> instance from configuration.

* id

form identifier in "form_handlers" (see configuration above)

must be string

required

* locale

language to use

must be string

required

* ctx

context object

should be hash reference

=item is_valid ( $hash_ref ) : boolean

See L<Catmandu::Validator>

=item last_errors : array

See L<Catmandu::Validator>

=item finalize : hash or undef

Convert valid hash to final record

Returns hash if valid, undef if unvalid.

=item clear : void

Restores form to it initial state

=back

=head1 WORKFLOW

=over

=item load form

Initial state is created as following:

* an object is created from the defaults in the field configuration

* if provided, the ctx is added to the defaults as '_ctx'

* a list of "before_fixes" can change this object, using for example information from the provided context

* '_ctx' is removed from the object at the end

=item GET /forms/:form_id?lang=:en

    my $session = session();
    my $params  = params();
    my $form_id = delete $params->{form_id};
    my $lang    = delete $params->{lang};

    my $form = LibreCat::Form->load(
        id     => $form_id,
        locale => $lang,
        ctx    => { session => $session }
    );

    #form_id not found in configuration
    $form or pass();

    template "forms/$form_id", { fif => $form->fif };

=item submit and validate form

In this state, the initial object is disregarded in favour of the submitted parameters

Non filled in parameters become an empty string.

After successfull validation the method "finalize" returns a "finished record".

This "finished record" is equal to the submitted parameters, but can be

changed by a list of "after_fixes"

=item POST /forms/:form_id?lang=:en

    my $session = session();
    my $params  = params();
    my $form_id = delete $params->{form_id};
    my $lang    = delete $params->{lang};

    my $form = LibreCat::Form->load(
        id     => $form_id,
        locale => $lang,
        ctx    => { session => $session }
    );

    #form_id not found in configuration
    $form or pass();

    my $errors;
    my $record;

    if ( $form->is_valid( $params ) ) {

        $record = $form->finalize();

        Catmandu->store->bag->add( $record );

    }
    else {

        $errors = $form->last_errors();

    }

    template "forms/$form_id", { fif => $form->fif, errors => $errors, record => $record };

=back

=cut

1;
