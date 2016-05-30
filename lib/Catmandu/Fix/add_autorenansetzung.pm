package Catmandu::Fix::add_autorenansetzung;

use Catmandu::Sane;
use Moo;

sub fix {
    my ($self, $pub) = @_;

    if (    $pub->{author}
        and ref $pub->{author} eq "ARRAY"
        and $pub->{author}->[0])
    {
        $pub->{first_author} = $pub->{author}->[0]->{full_name};

        foreach my $author (@{$pub->{author}}) {
            if (    !$author->{last_name}
                and !$author->{first_name}
                and $author->{full_name})
            {
                my @authnames = split ",", $author->{full_name};
                if (!@authnames) {
                    @authnames = split " ", $author->{full_name};
                }
                if (@authnames and \@authnames == 1) {
                    $author->{first_name} = $authnames[0];
                    $author->{last_name}  = $authnames[1];
                }
            }
            elsif (!$author->{last_name} and $author->{first_name}) {
                $author->{last_name} = $author->{first_name};
                delete $author->{first_name};
            }

            my $first_initial = substr $author->{first_name}, 0, 1
                if $author->{first_name};

            my @initials = split " ", $author->{first_name}
                if $author->{first_name};
            foreach (@initials) {
                $_ =~ s/^([a-zA-Z])[a-zA-Z]+\-([a-zA-Z])[a-zA-Z]+$/$1-$2/g;
                $_ =~ s/^([a-zA-Z])[a-zA-Z]+$/$1/g;
            }

            my @initials_dot = split " ", $author->{first_name}
                if $author->{first_name};
            foreach (@initials_dot) {
                $_ =~ s/^([a-zA-Z])[a-zA-Z]+\-([a-zA-Z])[a-zA-Z]+$/$1.-$2./g;
                $_ =~ s/^([a-zA-Z])[a-zA-Z]+$/$1./g;
            }

            $author->{autoren_ansetzung} = ();

            # "Kaufmann, Sabine-Marie Ann-Katrin"
            # "Müller, Karl Heinz"
            push @{$author->{autoren_ansetzung}}, "$author->{full_name}"
                if $author->{full_name};

            # "Kaufmann"
            # "Müller"
            push @{$author->{autoren_ansetzung}}, "$author->{last_name}"
                if $author->{last_name};

            # "Sabine-Marie Ann-Katrin Kaufmann"
            # "Karl Heinz Müller"
            push @{$author->{autoren_ansetzung}},
                "$author->{first_name} $author->{last_name}"
                if ($author->{first_name} and $author->{last_name});

            if ($first_initial) {

                # "Kaufmann, S"
                # "Müller, K"
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name}, $first_initial";

                # "Kaufmann, S."
                # "Müller, K."
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name}, $first_initial.";

                # "S Kaufmann"
                # "K Müller"
                push @{$author->{autoren_ansetzung}},
                    "$first_initial $author->{last_name}";

                # "S. Kaufmann"
                # "K. Müller"
                push @{$author->{autoren_ansetzung}},
                    "$first_initial. $author->{last_name}";
            }

            if (@initials and scalar @initials > 1) {
                my $string = "";
                $string = join('', @initials);

                # "Kaufmann S-MA-K"
                # "Müller KH"
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name} $string";

                # "Kaufmann, S-MA-K"
                # "Müller, KH"
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name}, $string";

                $string = "";
                $string = join(' ', @initials);

                # "Kaufmann S-M A-K"
                # "Müller K H"
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name} $string";

                # "Kaufmann, S-M A-K"
                # "Müller, K H"
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name}, $string";
            }

            if (@initials_dot and scalar @initials_dot > 1) {
                my $string = "";
                $string = join('.', @initials_dot);

                # "Kaufmann S.-M.A.-K."
                # "Müller K.H."
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name} $string";

                # "Kaufmann, S.-M.A.-K."
                # "Müller, K.H."
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name}, $string";

                $string = "";
                $string = join('. ', @initials_dot);

                # "Kaufmann S.-M. A.-K."
                # "Müller K. H."
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name} $string";

                # "Kaufmann, S.-M. A.-K."
                # "Müller, K. H."
                push @{$author->{autoren_ansetzung}},
                    "$author->{last_name}, $string";
            }
        }
    }

    $pub;
}

1;
