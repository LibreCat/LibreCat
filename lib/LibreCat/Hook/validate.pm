package LibreCat::Hook::validate;

use Catmandu::Sane;
use Catmandu::Fix;
use Catmandu::Util qw(require_package);
use LibreCat::App::Helper;
use Moo;

has name => (is => 'ro', default => sub {''});
has _fixer => (is => 'lazy');

sub _build_fixer {
    my $self = shift;

    my $bag = $self->name;
    $bag =~ s/(^[a-z_]+)\-.*/$1/;
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

    return Catmandu::Fix->new();
}

sub fix {
    my ($self, $data) = @_;

    my %opts;

    my $bag = $self->name;
    $bag =~ s/(^\w+)\-.*/$1/; # TODO: check the regex carfully
    state $fixes = {};
    my $fix = $fixes->{$bag} //= $self->_build_fixer();
    $fix->fix($data);

    # state $cite_fix = Catmandu::Fix->new(fixes => ["add_citation()"]);
    # $cite_fix->fix($data) unless $opts{skip_citation};

    state $validators = {};

    my $validator = $validators->{$bag} //= Catmandu::Util::require_package(ucfirst($bag),
            'LibreCat::Validator')->new;

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

};

1;
