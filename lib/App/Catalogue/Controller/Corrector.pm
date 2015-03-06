package App::Catalogue::Controller::Corrector;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(:is :array :human trim);
use App::Helper;
use Exporter qw/import/;
our @EXPORT = qw/delete_empty_fields correct_hash_array correct_writer correct_publid/;

sub delete_empty_fields {
    my $data = shift;

    foreach my $key (keys %$data){
    	my $ref = ref $data->{$key};

    	if($ref eq "ARRAY"){
    		if(!$data->{$key}->[0]){
    			delete $data->{$key};
    		}
    	}
    	elsif($ref eq "HASH"){
    		if(!%{$data->{$key}}){
    			delete $data->{$key};
    		}
    	}
    	else{
    		if($data->{$key} and $data->{$key} eq ""){
    			delete $data->{$key};
    		}
    	}
    }

    return $data;
}

sub correct_hash_array {
	my $data = shift;
	my $conf = h->config;
    my $tmp_type;
    if ($data->{type} =~ /^bi[A-Z]/) {
        $tmp_type = "bithesis";
    } else {
        $tmp_type = lc($data->{type});
    }
	my $fields = $conf->{forms}->{publicationTypes}->{$tmp_type}->{fields};

	foreach my $key (keys %$data){
		my $ref = ref $data->{$key};
		my $array_field = $conf->{forms}->{array_field};

		if($ref ne "ARRAY" and array_includes($array_field,$key)){
			$data->{$key} = [$data->{$key}];
		}
		if($ref eq "ARRAY" and !array_includes($array_field,$key)){
			$data->{$key} = $data->{$key}->[0];
		}
	}

	return $data;
}

sub correct_writer {
	my $data = shift;

	#$data->{writer_type} = "author" if !$data->{writer_type};
	my @writers = qw(author editor translator supervisor);
	
	foreach my $writer (@writers){
		if($data->{$writer}){
			foreach my $crea (@{$data->{$writer}}){
				$crea->{full_name} = $crea->{last_name} . ", " . $crea->{first_name};
			}
			$data->{"first_$writer"} = $data->{$writer}->[0]->{full_name} if $data->{$writer}->[0];
		}
	}

    #delete $data->{writer};
    #delete $data->{writer_type};

    return $data;
}

sub correct_publid {
	my $data = shift;
	
	if($data->{publication_identifier} and ref $data->{publication_identifier} eq "ARRAY"){
		my $publid_hash;
		foreach my $publid (@{$data->{publication_identifier}}){
			$publid_hash->{$publid->{type}} = [] if !$publid_hash->{$publid->{type}};
			push @{$publid_hash->{$publid->{type}}}, $publid->{value};
		}
		delete $data->{publication_identifier};
		$data->{publication_identifier} = $publid_hash;
	}
	if($data->{external_id} and ref $data->{external_id} eq "ARRAY"){
		my $publid_hash;
		foreach my $publid (@{$data->{external_id}}){
			next if $publid_hash->{$publid->{type}};
			$publid_hash->{$publid->{type}} = $publid->{value};
		}
		delete $data->{external_id};
		$data->{external_id} = $publid_hash;
	}
	if($data->{nasc}){
		my @nasc;
		@nasc = split(" ; ", $data->{nasc});
		delete $data->{nasc};
		$data->{nasc} = \@nasc;
	}
	if($data->{genbank}){
		my @genbank;
		@genbank = split(" ; ", $data->{genbank});
		delete $data->{genbank};
		$data->{genbank} = \@genbank;
	}
	
	return $data;
}

1;
