package Catmandu::Fix::file_date_updated;

=pod

=head1 NAME

Catmandu::Fix::file_date_updated - calculate the latest update date of record files

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

use Catmandu::Sane;
use POSIX qw(floor);
use Moo;

sub fix {
    my ($self, $data) = @_;

    return $data unless $data->{file};

    my @dates = ();

    for my $file (@{ $data->{file} }) {
	    push @dates , $file->{date_updated} if $file->{date_updated};
    }

    $data->{file_date_updated} = [ sort @dates ]->[-1] if @dates;

    $data;
}

1;
