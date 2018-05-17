package LibreCat::Hook::register_doi;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Catmandu;
use Moo;

sub fix {
    my ($self, $data) = @_;

    my $prefix = h->config->{doi}->{prefix};

    return $data
        unless $data->{doi}
        && $data->{doi} =~ /^$prefix/
        && $data->{status} eq "public";

    h->log->info("Register the publication at DataCite\n" . to_yaml($data));

    my $datacite_xml
        = Catmandu->export_to_string({%$data, uri_base => h->uri_base()},
        'Template', template => 'views/export/datacite.tt', xml => 1);

    h->log->debug("datacite_xml: $datacite_xml");

    my $job = {
        doi          => $data->{doi},
        landing_url  => h->uri_base() . "/record/$data->{_id}",
        datacite_xml => $datacite_xml
    };

    try {
        h->queue->add_job('datacite', $job);
    }
    catch {
        h->log->error("Could not register DOI: $_ -- $data->{_id}");
    };

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::register_doi - a LibreCat hook that registers a DOI at DataCite

=head1 SYNOPSIS

    doi:
      prefix: 10.5192/test

=head1 SEE ALSO

L<LibreCat>, L<LibreCat::Hook>, L<LibreCat::Worker::DataCite>

=cut
