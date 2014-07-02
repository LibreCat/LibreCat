package Catmandu::Fix::author_name;

use Catmandu::Sane;
use Moo;

has old_path => (fix_arg => 1);

sub fix {

	my ($self, $pub) = @_;
	my $name = $pub->{name};
	if($name ne ""){
		$name =~ s/^Herr //g;
		$name =~ s/^Frau //g;
		$name =~ s/^\s+|\s+$//g;
		$name =~ s/PD/PD\./g;
		
		my $first_name = ""; my $last_name = ""; my $title = "";
		if($name =~ /,/){
			($last_name, $first_name) = split /,/, $name;
			$first_name =~ s/^\s+|\s+$//g;
			$name = "";
		}
		
		if($name =~ /(.*nat\. |.*em\. |.*mult\. |.*h\.c\. |.*habil\. |.*i\.R\. |.*Ing\. |.*Biol\. |.*Psych\. |.*Ph.D\. |.*PhD |.*PD\. |.*phil\. |.*M\.A\. |.*Päd\. |.*Soz\. |.*Sozw\. |.*Chem\. |.*soc\. )(.*)/){
			$title = $1;
			$name = $2;
		}
		
		if($name =~ /(.*Prof\..* Dr\. |.*Prof\. |.*Dr\. |.*Professor )(.*)/){
			if($title ne ""){
				$title .= " ".$1;
			}
			else {
				$title = $1;
			}
			$name = $2;
		}
		
		if($name =~ /(.*) (von .*|van .*|da .*|Graf v. .*)/){
			$first_name = $1;
			$last_name = $2;
			$name = "";
		}
		
		if($name =~ /(.*) (.*)/){
			$first_name = $1;
			$last_name = $2;
		}
		
		return ($title, $first_name, $last_name);
	} else {
		return ("", "", "");
	}
	
}

}

1;

=head1 NAME

	Catmandu::Fix::author_name

=cut
