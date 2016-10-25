package LibreCat::Role;

use Catmandu::Sane;
use Catmandu::Util qw(require_package array_includes);
use Moo;
use namespace::clean;

with 'Catmandu::Logger';

has rule_config => (is => 'ro', default => sub {+{}});
has rules       => (is => 'ro', default => sub {[]});
has params      => (is => 'ro', default => sub {[]});
has match_code => (is => 'lazy', init_arg => undef);
has matcher    => (is => 'lazy', init_arg => undef);

sub may {
    $_[0]->matcher->($_[1], $_[2], $_[3], $_[4]);
}

sub _build_matcher {
    my ($self) = @_;
    eval $self->match_code;
}

sub _build_match_code {
    my ($self)      = @_;
    my $rule_config = $self->rule_config;
    my $rules       = $self->rules;
    my $params      = $self->params;
    my $captures    = {};

    my $sub = q|
sub {
    my ($subject, $verb, $object, $params) = @_;
    my $match = 0;
    my $param;
|;

    for my $rule (@$rules) {
        my ($can, $verb, $type, $filter, $param) = @$rule;
        my $toggle = $can eq 'can' ? '1' : '0';
        my $conditions = [];

        if ($verb ne '*') {
            unshift @$conditions, "\$verb eq '$verb'";
        }

        if ($type) {
            my $type_pattern = quotemeta($type);

            unshift @$conditions, "\$object";

            if ($type ne '*') {
                unshift @$conditions,
                    "\$object->{_type} && \$object->{_type} =~ /^$type_pattern/";
            }

            if ($filter) {
                if (!$captures->{$filter} && $rule_config->{$filter}) {
                    my $pkg = $rule_config->{$filter}{package} || $filter;
                    $captures->{$filter} = require_package $pkg,
                        'LibreCat::Rule';
                }

                if ($captures->{$filter} && defined $param) {
                    unshift @$conditions,
                        "\$_${filter}->test(\$subject, \$object, \$param)";
                }
                elsif ($captures->{$filter}) {
                    unshift @$conditions,
                        "\$_${filter}->test(\$subject, \$object)";
                }
                elsif (defined $param) {
                    unshift @$conditions,
                        "\$object->{'$filter'} && \$object->{'$filter'} eq \$param";
                }
                else {
                    unshift @$conditions, "\$object->{'$filter'}";
                }
            }
        }

        if (defined $param && array_includes($self->params, $param)) {
            $sub
                .= qq|    \$param = \$params->{'$param'} // Catmandu::BadVal->throw("missing role param '$param'");\n|;
        }
        elsif (defined $param) {
            $sub .= qq|    \$param = '$param';\n|;
        }

        my $indent = scalar(@$conditions) * 4;
        my $spaces = ' ' x $indent;
        my $code   = qq|    \$match = $toggle;|;
        for my $cond (@$conditions) {
            $code = qq|    if ($cond) {\n$spaces$code\n$spaces}|;
            $indent -= 4;
            $spaces = ' ' x $indent;
        }
        $sub .= qq|$code\n|;
    }
    $sub .= qq|    \$match;\n}\n|;

    for my $var (keys %$captures) {
        my $pkg = $captures->{$var};
        $sub = qq|\nmy \$_$var = ${pkg}->new;$sub|;
    }

    $self->log->debug($sub) if $self->log->is_debug;

    $sub;
}

1;

__END__

