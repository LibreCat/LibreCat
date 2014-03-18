package Catmandu::Fix::validate;

use Catmandu::Sane;
use Catmandu::Util qw/trim/;
use Business::ISSN;
use Business::ISBN;
use Moo;

sub fix {
	my ($self, $data) = @_;

	foreach my $k (keys %$data) {
		trim $data->{$k};
	}

	# filter bad chars, but how?
	$pub;
}

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

1;
