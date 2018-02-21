package Catmandu::Fix::file_date_updated;

use Catmandu::Sane;
use POSIX qw(floor);
use Moo;

sub fix {
    my ($self, $data) = @_;

    my @dates = ();

    for my $file (@{ $data->{file} }) {
	    my $date_updated = $file->{date_updated};
	    push @dates , $date_updated;
    }

    $data->{file_date_updated} = [ sort @dates ]->[-1] if @dates;

    $data;
}

1;

__END__

=pod

=head1 NAME

file_date_updated - calculate the latest update date of record files

=head1 SYNOPSIS

    # A new field file_date_updated will be created in the
    # record with the latest update date for files at indexation time

    # In store.yml section search.options.bags:

    publication:
      fix:
          - file_date_updated()
      cql_mapping:
          ...

    # Search for files updates after a date
    $ bin/librecat publication list "file_date_updated > 2017-01-01T00:00:00Z"

=cut
