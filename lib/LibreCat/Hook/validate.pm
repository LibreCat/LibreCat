package LibreCat::Hook::validate;

use Catmandu::Sane;
use Catmandu::Fix;
use Catmandu::Util qw(require_package);
use LibreCat::App::Helper;
use Moo;
use namespace::clean;

has bag => (is => 'ro', required => 1);
has _fixer     => (is => 'lazy');
has _validator => (is => 'lazy');

sub _build__fixer {
    my $self = shift;

    my $bag  = $self->bag;
    my $file = "update_$bag.fix";
    h->log->debug("searching for fix '$file'");

    for my $p (@{LibreCat->layers->fixes_paths}) {
        h->log->debug("testing `$p/$file'");
        if (-r "$p/$file") {
            h->log->debug("found '$p/$file'");
            return Catmandu::Fix->new(fixes => ["$p/$file"]);
        }
    }

    h->log->error("can't find a fixer for: '$file'");

    return;
}

sub _build__validator {
    my $self = shift;
    my $bag  = $self->bag;
    require_package(ucfirst($bag), 'LibreCat::Validator')->new;
}

sub fix {
    my ($self, $data) = @_;

    my %opts;

    my $bag       = $self->bag;
    my $fix       = $self->_fixer;
    my $validator = $self->_validator;

    $data = $fix->fix($data) if $fix;

    # TODO
    # state $cite_fix = Catmandu::Fix->new(fixes => ["add_citation()"]);

    my @white_list = $validator->white_list;

    for my $key (keys %$data) {
        unless (grep(/^$key$/, @white_list)) {
            h->log->debug("deleting invalid key: $key");
            delete $data->{$key};
        }
    }

    unless ($validator->is_valid($data)) {
        h->log->error($data->{_id} . " not a valid publication!");
        h->log->error($validator->last_errors);
        $data->{_validation_errors} = $validator->last_errors;
    }

}

1;
