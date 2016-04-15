package LibreCat::Cmd::mailer;

use Catmandu::Sane;

use parent 'LibreCat::Worker';

sub function_spec {
    my ($self) = @_;
    (
        ['send_mail', 0, \&do_send_mail, {}],
    );
}

sub do_send_mail {
    system 'echo "mailing ... " >> /tmp/librecat-mail.log';
    sleep 5;
}

1;

