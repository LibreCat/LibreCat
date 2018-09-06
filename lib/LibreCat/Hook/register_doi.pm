package LibreCat::Hook::register_doi;

use Catmandu::Sane;
use Carp;
use LibreCat qw(:self);
use Moo;

with 'LibreCat::Logger';

sub fix {
    my ($self, $data) = @_;

    my $conf   = librecat->config->{doi};
    my $prefix = $conf->{prefix};
    my $queue  = $conf->{queue};

    unless ($prefix && $queue) {
        $self->log->fatal("Need a doi.prefix and doi.queue configuration");
        return $data;
    }

    return $data
        unless $data->{doi}
        && $data->{doi} =~ /^$prefix/
        && $data->{status} eq "public";

    $data->{publisher} = $conf->{default_publisher} unless $data->{publisher};

    if ($self->log->is_debug) {
        $self->log->debugf(
            "Register the publication at DataCite %s", $data);
    }

    my $job = {
        doi         => $data->{doi},
        landing_url => librecat->config->{uri_base} . "/record/$data->{_id}",
        record      => $data,
    };

    try {
        librecat->queue->add_job($queue, $job);
    }
    catch {
        $self->log->errorf("Could not register DOI: %s", $data);
    };

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::register_doi - a LibreCat hook that registers a DOI

=head1 CONFIGURATION

    # See: https://github.com/LibreCat/LibreCat/wiki/DOI-Registration for more information
    
    doi:
       prefix: "10.5072/test"
       queue: datacite
       default_publisher: LibreCat Publishing System

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Hook>, L<LibreCat::Worker::Datacite>

=cut
