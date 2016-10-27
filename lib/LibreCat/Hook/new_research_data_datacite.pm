package LibreCat::Hook::new_research_data_datacite;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Dancer::Plugin::Email;
use LibreCat::Worker::DataCite;
use Catmandu;
use Moo;

sub fix {
    my ($self, $data) = @_;

    return $data
        unless $data->{doi}
        && $data->{type} eq "research_data"
        && $data->{status} eq "public";

    h->log->info("Register the publication at DataCite");

    try {
        my $registry = LibreCat::Worker::DataCite->new(
            user     => h->config->{doi}->{user},
            password => h->config->{doi}->{passwd}
        );

        my $datacite_xml
            = Catmandu->export_to_string({%$data, host => h->host},
            'Template', template => 'views/export/datacite.tt');

        h->log->debug("datacite_xml: $datacite_xml");

        $registry->work(
            {
                doi          => $data->{doi},
                landing_url  => h->host . "/data/$data->{_id}",
                datacite_xml => $datacite_xml
            }
        );
    }
    catch {
        h->log->error("Could not register DOI: $_ -- $data->{_id}");
    };

    $data;
}

1;
