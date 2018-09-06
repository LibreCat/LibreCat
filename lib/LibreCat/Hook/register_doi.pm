package LibreCat::Hook::register_doi;

use Catmandu::Sane;
use Carp;
use Dancer qw(:syntax);
use LibreCat qw(:self);
use Moo;

sub fix {
    my ($self, $data) = @_;

    my $conf   = librecat->config->{doi};
    my $prefix = $conf->{prefix} // croak "Need a prefix";
    my $queue  = $conf->{queue} // croak "Need a queue";

    return $data
        unless $data->{doi}
        && $data->{doi} =~ /^$prefix/
        && $data->{status} eq "public";

    $data->{publisher} = $conf->{publisher} unless $data->{publisher};

    librecat->log->debug(
        "Register the publication at DataCite\n" . to_yaml($data));

    my $job = {
        doi         => $data->{doi},
        landing_url => librecat->config->{uri_base} . "/record/$data->{_id}",
        record      => $data,
    };

    try {
        librecat->queue->add_job($queue, $job);
    }
    catch {
        librecat->log->error("Could not register DOI: $_" . to_yaml($data));
    };

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::register_doi - a LibreCat hook that registers a DOI

=head1 CONFIGURATION

    hook:
      register_doi:
        prefix: 10.5192/test
        queue: datacite
        publishser: LibreCat University

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Hook>, L<LibreCat::Worker::Datacite>

=cut
