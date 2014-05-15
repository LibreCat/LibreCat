package Catmandu::Fix::clean_language;

use Catmandu::Sane;
use Moo;

sub fix {
    my ( $self, $pub ) = @_;
    
    delete $pub->{language} if $pub->{language};
        
    if ($pub->{usesLanguage} and ref $pub->{usesLanguage} eq "ARRAY") {
    	
    	foreach my $lang (@{$pub->{usesLanguage}}){
    		my $language;
    		$language->{iso} = $lang->{languageCode};
    		foreach my $lname (@{$lang->{name}}) {
    			if ($lname->{lang} eq 'eng') {
    				$language->{name} = $lname->{text};
    			}
    		}
    		push @{$pub->{language}}, $language;
    	}
    	
    	delete $pub->{usesLanguage};
    	
    }
    
    if ($pub->{usesOriginalLanguage}){
    	if(ref $pub->{usesOriginalLanguage} eq "ARRAY") {
    		foreach my $lang (@{$pub->{usesOriginalLanguage}}){
    			my $language;
    			$language->{iso} = $lang->{languageCode};
    			foreach my $lname (@{$lang->{name}}) {
    				if ($lname->{lang} eq 'eng') {
    					$language->{name} = $lname->{text};
    				}
    			}
    			push @{$pub->{original_language}}, $language;
    		}
    	}
    	else{
    		my $language;
    		$language->{iso} = $pub->{usesOriginalLanguage}->{languageCode};
    		foreach my $lname (@{$pub->{usesOriginalLanguage}->{name}}) {
    			if ($lname->{lang} eq 'eng') {
    				$language->{name} = $lname->{text};
    			}
    		}
    		push @{$pub->{original_language}}, $language;
    	}
    	
    	delete $pub->{usesOriginalLanguage};
    	
    }
    
    $pub;
}

1;
