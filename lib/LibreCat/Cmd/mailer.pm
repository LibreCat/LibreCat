package LibreCat::Cmd::mailer;

use Catmandu::Sane;

use parent 'LibreCat::Worker';

sub function_spec {
    my ($class) = @_;
    (
        ['send_mail', 0, \&do_send_mail, {}],
    );
}

sub do_send_mail {
    my ($job, $workload) = @_;
    system 'echo "'.ref($workload).'" >> /tmp/librecat-mail.log';
    sleep 1;
}

1;

