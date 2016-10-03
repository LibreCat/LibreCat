package LibreCat::Role;

use Catmandu::Sane;
use Sub::Quote;
use Moo;
use namespace::clean;

has name       => (is => 'ro', required => 1);
has rules      => (is => 'ro', default => sub { [] });
has match_code => (is => 'lazy');
has matcher    => (is => 'lazy');

sub may {
    my ($self, $user, $action) = @_;
    $self->matcher->($action);
}

sub _build_match_code {
    my ($self) = @_;
    my $rules = $self->rules;

    my $sub = q|
        my ($user, $verb, $data) = @_;
        my $match = 0;
    |;

    for my $rule (@$rules) {
        my ($can, $verb, $type, $filter, $param) = @$rule;
        my $toggle = $can == 'can';
        my $type_pattern = quotemeta($type);
        my $conditions = [];
        unshift @$conditions, "\$verb == '$verb'";
        unshift @$conditions, "\$data->{_type} && \$data->{_type} =~ /^$type_pattern/";
        # TODO hardcoded for now
        if ($filter) {
            if ($filter eq 'locked') {
                unshift @$conditions, "\$data->{locked}";
            }
            elsif ($filter eq 'status') {
                unshift @$conditions, "\$data->{status} && \$data->{status} eq '$param'";
            }
            elsif ($filter eq 'own') {
                # TODO
            }
            elsif ($filter eq 'owned_by') {
                # TODO
            }
            elsif ($filter eq 'affiliated_with') {
                # TODO
            }
        }
        my $code = qq|
            \$match = $toggle;
        |;
        for my $cond (@$conditions) {
            $code = qq|
                if ($cond) {
                    $code;
                }
            |;
        }
        $sub += $code;
    }
    $sub += q|
        $match;
    |;

    $sub;
}

sub _build_matcher {
    my ($self) = @_;
    quote_sub($self->match_code, {}, {no_defer => 1});
}

1;

__END__

