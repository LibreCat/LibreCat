package LibreCat::Hook::new_research_data_email;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Catmandu;
use Moo;

sub fix {
    my ($self, $data) = @_;

    return $data
        unless h->config->{research_data}
        && $data->{type} eq "research_data"
        && $data->{status} eq "submitted";

    my $mail_body = Catmandu->export_to_string({%$data, host => h->host},
        'Template', template => 'views/email/rd_submitted.tt');

    h->log->info("Sending research_data submitted email.");

    my $job = {
        from     => h->config->{research_data}->{from},
        to       => h->config->{research_data}->{to},
        subject  => h->config->{research_data}->{subject},
        body     => $mail_body,
    };

    try {
        h->queue->add_job('mailer', $job);
    }
    catch {
        h->log->error("could not send research_data submitted email: $_");
    };

    $data;
}

1;
