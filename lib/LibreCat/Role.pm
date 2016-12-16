package LibreCat::Role;

use Catmandu::Sane;
use Catmandu::Util qw(require_package array_includes);
use B ();
use Moo;
use namespace::clean;

with 'Catmandu::Logger';

has rules       => (is => 'ro', default => sub {[]});
has match_code  => (is => 'lazy', init_arg => undef);
has matcher     => (is => 'lazy', init_arg => undef);

sub may {
    $_[0]->matcher->($_[1], $_[2], $_[3], $_[4]);
}

sub _build_matcher {
    my ($self) = @_;
    eval $self->match_code;
}

sub _build_match_code {
    my ($self)      = @_;
    my $rules       = $self->rules;
    my $num_vars    = 0;
    my $sub = q|
sub {
    my ($subject, $verb, $object, $params) = @_;
    my $match = 0;
|;

    for my $rule (@$rules) {
        my ($can, $verb, $type, $filter_name, @filter_args) = @$rule;
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

            if ($filter_name) {
                my $var  = '$filter_'.$num_vars++;
                my $pkg  = require_package($filter_name, 'LibreCat::Rule');
                my $args = join(', ', map { B::perlstring($_) } @filter_args);

                $sub = qq|\nmy $var = ${pkg}->new(args => [$args]);$sub|;
                unshift @$conditions,
                    "${var}->test(\$subject, \$object, \$params)";
            }
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

    $self->log->debug($sub) if $self->log->is_debug;

    $sub;
}

1;

__END__

