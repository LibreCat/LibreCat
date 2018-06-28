package LibreCat::Hook::register_doi;

use Catmandu::Sane;
use LibreCat qw(:self);
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Catmandu;
use Moo;

sub fix {
    my ($self, $data) = @_;

    my $prefix = librecat->config->{doi}->{prefix};

    return $data
        unless $data->{doi}
        && $data->{doi} =~ /^$prefix/
        && $data->{status} eq "public";

    $data->{publisher} = librecat->config->{doi}->{publisher} unless $data->{publisher};

    librecat->log->debug("Register the publication at DataCite\n" . to_yaml($data));

    my $job = {
        doi          => $data->{doi},
        landing_url  => h->uri_base() . "/record/$data->{_id}",
        record => $rec,
    };

    try {
        librecat->queue->add_job('datacite', $job);
    }
    catch {
        librecat->log->error("Could not register DOI: $_ -- $data->{_id}");
    };

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::register_doi - a LibreCat hook that registers a DOI

=head1 CONFIGURATION

    doi:
      prefix: 10.5192/test
      worker: datacite

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Hook>, L<LibreCat::Worker::Datacite>

=cut
