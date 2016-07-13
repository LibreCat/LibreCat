#!/usr/bin/env perl

use Catmandu;

Catmandu->load('.');

my $date    = localtime time;
my $schemas = Catmandu->config->{schemas};
my @fields  = ('machine name' , 'data type' , 'description' , 'mandatory');

print "{*Generated on $date  by  $0*}\n";

for my $section (sort keys %$schemas) {
    print "## $section\n\n";

    table_header(@fields);
    print_proterties($schemas->{$section});

    print "\n";
}

sub print_proterties {
    my ($section,$prefix) = @_;

    $prefix = '' unless $prefix;

    my $definitions = $section->{'definitions'} // {};
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
                print_proterties($prop->{items},"-$name.");
            }
            elsif ($prop->{items}->{'$ref'}) {
                my $def = $prop->{items}->{'$ref'};
                $def =~ s/.*\///;
                print_proterties($definitions->{$def},"-$name.");
            }
        }
        elsif ($prop->{properties}) {
            print_proterties($prop,"-$name.");
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
