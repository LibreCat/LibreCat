package LibreCat::Hook::publication_file_sort;
use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Moo;

with "LibreCat::Logger";

sub fix {
    my ($self, $data) = @_;

    $data->{file} = [ sort { $a->{file_name} cmp $b->{file_name} } @{ $data->{file} } ];

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::publication_file_sort - sorts publication files on file_name before storing

=head1 DESCRIPTION

Normally, the order of the files in a publication.file are preserved during a publication-update.

With this hook, you can change that, and sort them on file_name.

This should only be used as a before fix, and during a "publication-update".

=head1 SYNOPSIS

    # in your config
    hooks:
      publication-update:
        before_fixes:
         - publication_file_sort

=cut
