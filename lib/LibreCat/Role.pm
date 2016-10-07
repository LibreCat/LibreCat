package LibreCat::Role;

use Catmandu::Sane;
use Moo;
use namespace::clean;

has rules      => (is => 'ro', default => sub { [] });
has match_code => (is => 'lazy');
has matcher    => (is => 'lazy');

sub may {
    $_[0]->matcher->($_[1], $_[2], $_[3]);
}

sub _build_match_code {
    my ($self) = @_;
    my $rules = $self->rules;

    my $sub = q|
sub {
    my ($subject, $verb, $object) = @_;
    my $match = 0;
|;

    for my $rule (@$rules) {
        my ($can, $verb, $type, $filter, $param) = @$rule;
        my $toggle = $can eq 'can' ? '1' : '0';
        my $conditions = [];
        unshift @$conditions, "\$verb eq '$verb'";
        if ($type) {
            my $type_pattern = quotemeta($type);
            unshift @$conditions, "\$object";
            unshift @$conditions, "\$object->{_type} && \$object->{_type} =~ /^$type_pattern/";

            # TODO hardcoded for now
            if ($filter) {
                if ($filter eq 'own') {
                    # TODO
                }
                elsif ($filter eq 'owned_by') {
                    # TODO
                }
                elsif ($filter eq 'affiliated_with') {
                    # TODO
                }
                elsif (defined $param) {
                    unshift @$conditions, "\$object->{'$filter'} && \$object->{'$filter'} eq '$param'";
                }
                else {
                    unshift @$conditions, "\$object->{'$filter'}";
                }
            }
        }
        my $indent = scalar(@$conditions) * 4;
        my $spaces = ' ' x $indent;
        my $code = qq|    \$match = $toggle;|;
        for my $cond (@$conditions) {
            $code = qq|    if ($cond) {\n$spaces$code\n$spaces}|;
            $indent -= 4;
            $spaces = ' ' x $indent;
        }
        $sub .= qq|$code\n|;
    }
    $sub .= qq|    \$match;\n}\n|;

    $sub;
}

sub _build_matcher {
    eval $_[0]->match_code;
}

1;

__END__

