package LibreCat::Hook::check_publication_duplicates;

use Catmandu::Sane;
use LibreCat::Dedup::Publication;
use Moo;

has detector => (
    is => 'lazy',
);

sub _build_detector {
    LibreCat::Dedup::Publication->new();
}

sub fix {
    my ($self, $data) = @_;

    my $dup = $self->detector->find_duplicate($data);

    if ($dup && $dup->[0]) {
        $data->{message} .= "/ possible duplicates: " . join(',', @$dup);
    }

    return $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::check_for_duplicates - a hook to check records for potential duplicates

=head1 SYNPOSIS

    # in your config
    hooks:
      import-new-crossref:
        before_fixes:
         - check_publication_duplicates

=cut
