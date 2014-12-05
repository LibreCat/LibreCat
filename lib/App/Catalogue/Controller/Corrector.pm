package App::Catalogue::Controller::Corrector;

use Catmandu::Sane;
use Catmandu;
use App::Helper;
use Exporter qw/import/;
our @EXPORT = qw/delete_empty_fields correct_hash_array/;

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
	my $fields = $conf->{forms}->{publicationTypes}->{$data->{type}}->{fields};

	foreach my $key (keys %$data){
		my $ref = ref $data->{$key};
		my $fields_tab = $fields->{basic_fields}->{$key} || $fields->{file_upload}->{$key} || $fields->{supplementary_fields}->{$key} || $fields->{related_material}->{$key};

		if($ref ne "ARRAY" and $fields_tab->{multiple}){
			$data->{$key} = [$data->{$key}];
		}
	}

	return $data;
}

1;
