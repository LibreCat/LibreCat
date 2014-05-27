package Catmandu::Fix::add_editorenansetzung;

use Catmandu::Sane;
use Moo;

sub fix {
    my ( $self, $pub ) = @_;
        
    if ( $pub->{editor} and ref $pub->{editor} eq "ARRAY" and $pub->{editor}->[0]) {
    	$pub->{first_editor} = $pub->{editor}->[0]->{full_name};
    		
    	foreach my $editor (@{$pub->{editor}}){
    		if(!$editor->{last_name} and !$editor->{first_name} and $editor->{full_name}){
    			my @ednames = split ",", $editor->{full_name};
    			if (!@ednames){
    				@ednames = split " ", $editor->{full_name};
    			}
    			if(@ednames and \@ednames == 1){
    				$editor->{first_name} = $ednames[0];
    				$editor->{last_name} = $ednames[1];
    			}
    		}
    		elsif (!$editor->{last_name} and $editor->{first_name}){
    			$editor->{last_name} = $editor->{first_name};
    			delete $editor->{first_name};
    		}
    		
    		my $first_initial = substr $editor->{first_name}, 0, 1 if $editor->{first_name};
    		
    		my @initials = split " ", $editor->{first_name} if $editor->{first_name};
    		foreach (@initials){
    			$_ =~ s/^([a-zA-Z])[a-zA-Z]+\-([a-zA-Z])[a-zA-Z]+$/$1-$2/g;
    			$_ =~ s/^([a-zA-Z])[a-zA-Z]+$/$1/g;
    		}
    		
    		my @initials_dot = split " ", $editor->{first_name} if $editor->{first_name};
    		foreach (@initials_dot){
    			$_ =~ s/^([a-zA-Z])[a-zA-Z]+\-([a-zA-Z])[a-zA-Z]+$/$1.-$2./g;
    			$_ =~ s/^([a-zA-Z])[a-zA-Z]+$/$1./g;
    		}
    		
    		$editor->{editoren_ansetzung} = ();
    		
    		# "Kaufmann, Sabine-Marie Ann-Katrin"
    		# "Müller, Karl Heinz"
    		push @{$editor->{editoren_ansetzung}}, "$editor->{full_name}" if $editor->{full_name};
    		
    		# "Kaufmann"
    		# "Müller"
    		push @{$editor->{editoren_ansetzung}}, "$editor->{last_name}" if $editor->{last_name};
    		
    		# "Sabine-Marie Ann-Katrin Kaufmann"
    		# "Karl Heinz Müller"
    		push @{$editor->{editoren_ansetzung}}, "$editor->{first_name} $editor->{last_name}" if ($editor->{first_name} and $editor->{last_name});
    		
    		
    		if($first_initial){
    			# "Kaufmann, S"
    			# "Müller K"
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name}, $first_initial";
    			
    			# "Kaufmann, S."
    			# "Müller, K."
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name}, $first_initial.";
    			
    			# "S Kaufmann"
    			# "K Müller"
    			push @{$editor->{editoren_ansetzung}}, "$first_initial $editor->{last_name}";
    			
    			# "S. Kaufmann"
    			# "K. Müller"
    			push @{$editor->{editoren_ansetzung}}, "$first_initial. $editor->{last_name}";
    		}
    		
    		if(@initials and scalar @initials > 1){
    			my $string = "";
    			$string = join('', @initials);
    			
    			# "Kaufmann S-MA-K"
    			# "Müller KH"
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name} $string";
    			
    			# "Kaufmann, S-MA-K"
    			# "Müller, KH"
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name}, $string";
    			
    			$string = "";
    			$string = join(' ', @initials);
    			# "Kaufmann S-M A-K"
    			# "Müller K H"
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name} $string";
    			# "Kaufmann, S-M A-K"
    			# "Müller, K H"
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name}, $string";
    		}
    		
    		if(@initials_dot and scalar @initials_dot > 1){
    			my $string = "";
    			$string = join('.', @initials_dot);
    			# "Kaufmann S.-M.A.-K."
    			# "Müller K.H."
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name} $string";
    			# "Kaufmann, S.-M.A.-K."
    			# "Müller, K.H."
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name}, $string";
    			
    			$string = "";
    			$string = join('. ', @initials_dot);
    			# "Kaufmann S.-M. A.-K."
    			# "Müller K. H."
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name} $string";
    			# "Kaufmann, S.-M. A.-K."
    			# "Müller, K. H."
    			push @{$editor->{editoren_ansetzung}}, "$editor->{last_name}, $string";
    		}
    	}
    }

    $pub;
}

1;
