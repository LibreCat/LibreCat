package LibreCat::Cmd::schemas;

use Catmandu::Sane;
use Catmandu;
use App::Helper;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat schemas [options] list
librecat schemas [options] get SCHEMA
librecat schemas [options] markdown

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/(list|get|markdown)/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    binmode(STDOUT, ":encoding(utf-8)");

    if ($cmd eq 'list') {
        return $self->_list(@$args);
    }
    elsif ($cmd eq 'get') {
        return $self->_get(@$args);
    }
    elsif ($cmd eq 'markdown') {
        return $self->_markdown(@$args);
    }
}

sub _list {
    my $h     = App::Helper::Helpers->new;

    my $schemas = $h->config->{schemas};

    for my $schema (keys %$schemas) {
        print "$schema\n";
    }

    return 0;
}

sub _get {
    my ($self,$name) = @_;

    croak "get - need a schema name" unless $name;

    my $h     = App::Helper::Helpers->new;

    my $schema = $h->config->{schemas}->{$name};

    croak "get - no such schema '$name'" unless $schema;

    my $json = Catmandu->export_to_string($schema,'JSON', pretty => 1 , array => 0);

    print "$json\n";

    return 0;
}

sub _markdown {
    my $h     = App::Helper::Helpers->new;

    my $schemas = $h->config->{schemas};
    my $date    = localtime time;
    my @fields  = ('machine name' , 'data type' , 'description' , 'mandatory');

    print "{*Generated on $date by '$0 schemas markdown'*}\n\n";

    for my $section (sort keys %$schemas) {
        print "## $section\n\n";

        my $definitions = $schemas->{$section}->{'definitions'} // {};

        table_header(@fields);
        print_properties($schemas->{$section},'',$definitions);

        print "\n";
    }

    return 0;
}

sub print_properties {
    my ($section,$prefix,$definitions) = @_;

    $prefix = '' unless $prefix;

    my $properties  = $section->{'properties'} // {};
    my $required    = $section->{'required'} // [];

    for my $name (sort keys %$properties) {
        my $prop         = $properties->{$name};
        my $type         = prop_type($prop);
        my $pattern      = prop_pattern($prop);

        $type .= " ($pattern)" if $pattern;

        my $enumeration  = prop_enumeration($prop);

        $type .= " $enumeration" if $enumeration;

        my $description  = $prop->{description} // '';
        my $mandatory    = grep({ $_ eq $name } @$required) ? 'Y' : '';

        table_row("$prefix$name",$type,$description,$mandatory);

        if ($prop->{items}) {
            if ($prop->{items}->{properties}) {
                print_properties($prop->{items},"-$name.",$definitions);
            }
            elsif ($prop->{items}->{'$ref'}) {
                my $def = $prop->{items}->{'$ref'};
                $def =~ s/.*\///;
                die "can't find $def" unless $definitions->{$def};
                print_properties($definitions->{$def},"-$prefix$name.",$definitions);
            }
        }
        elsif ($prop->{properties}) {
            print_properties($prop,"-$name.",$definitions);
        }
    }
}

sub table_header {
    my (@data) = @_;

    print "| " . join(" | ", @data) . " |\n";
    print "| " . join(" | ", map( '---', @data)) . " |\n";
}

sub table_row {
    my (@data) = @_;

    print "| " . join(" | ", @data) . " |\n";
}

sub prop_type {
    my ($prop) = @_;

    if ($prop->{type}) {
        return $prop->{type};
    }
    elsif ($prop->{oneOf}) {
        my @types = map {
            if ($_->{type}) {
                prop_type($_);
            }
            elsif ($_->{enum}) {
                prop_enumeration($_);
            }
        }  @{$prop->{oneOf}};
        return join(" or ", @types);
    }
}

sub prop_pattern {
    my ($prop) = @_;

    $prop->{pattern} && length($prop->{pattern}) < 15 ?
        $prop->{pattern} : undef;
}

sub prop_enumeration {
    my ($prop) = @_;

    return undef unless $prop->{enum};

    my $str = "<ul type=\"square\">";

    for (@{$prop->{enum}}){
        $str .= "<li>$_</li>";
    }

    $str .= "</ul>";
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::schemas - manage librecat schemas

=head1 SYNOPSIS

    librecat schemas list
    librecat schemas [options] get SCHEMA
    librecat schemas [options] markdown

=cut
