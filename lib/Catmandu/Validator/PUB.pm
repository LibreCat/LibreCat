package Catmandu::Validator::PUB;

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Business::ISSN;
use Business::ISBN;
use Moo;

with 'Catmandu::Validator';

has handler => (is => 'rw', required => 1,
	isa => sub {
		Catmandu::BadArg->throw("handler should be a CODE reference")
			unless ref $_[0] eq 'CODE';
		},
	);

sub validate_data {
	my ($self, $data) = @_;

	my $error = &{$self->handler}($data);
    $error = [$error] unless !$error || ref $error eq 'ARRAY';

    # id, year
    (is_integer $data->{_id}) && (push @$error, "Invalid _id, must be integer");
    (is_integer $data->{year} && 1950 < $data->year < 2020) && (push @$error, "Invalid year.");

    # integer fields
    foreach (qw/volume issue pmid inspire wos reportNumber/) {
    	(is_integer $data->{$_}) && (push @$error, "$_ must be integer.");
    }
    
    ## boolean fields
    foreach (qw/external popularScience qualityControlled ubiFunded/) {
    	($data->{$_} =~ /0|1/) && (push @$error, "$_ must be boolean (0 or 1).");
    }

    # doi
    (if $data->{doi} =~ /^http/) {
    	$data->{doi} =~ s/http:\/\/doi.org\///;
    	$data->{doi} =~ s/http:\/\/dx.doi.org\///;
    }

    # issn, isbn
    $data->{tmp} = $data->{issn};
    delete $data->{issn};
    foreach my $i (@{$data->{tmp}}) {
    	my $obj = Business::ISSN->new($i) || push @$error, "issn error";

		if ($obj->is_valid) {
			push @{$data->{issn}}, $obj->as_string;
		} else {
			push @$error "Issn invalid";
		}
    }
    delete $data->{tmp};

    return $data;

}

1;

__END__
sub _normalize_issn {
	my $id = shift;

	my $obj = Business::ISSN->new($id) || return 0;

	if ($obj->is_valid) {
		return $obj->as_string;
		} else {
			return 0;
		}
}

sub _normalize_isbn {
	my $id = shift;

	my $obj = Business::ISBN->new($id) || return 0;

	if ($obj->is_valid) {
		return $obj->as_string;
		} else {
			return 0;
		}
}
