package LibreCat::Worker::Mailer;

use Catmandu::Sane;
use Email::Sender::Simple qw(sendmail);
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

sub work {
    my ($self, $opts) = @_;

    $self->log->debugf("sending mail to: %s", $opts);
    my $mail = Email::Simple->create(
        header => [
            To      => $opts->{to},
            From    => $opts->{from},
            Subject => $opts->{subject},
        ],
        body => $opts->{body},
    );

    try {
        sendmail($mail);
        $self->log->debug("sent mail successfully to $opts->{to}");
    }
    catch {
        $self->log->error("send mail error: $_");
    };
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::Mailer - a worker for mail notifications

=head1 SYNOPSIS

    use LibreCat::Worker::Mailer;

    my $mailer = LibreCat::Worker::Mailer->new;
    $mailer->work({
        to => 'me',
        from => 'system_mailer',
        subject => 'important',
        body => 'hello world',
    });

    # or better queue it via helper functions

    use LibreCat::App::Helper;

    my $job = {
        to => 'me',
        from => 'system_mailer',
        subject => 'important',
        body => 'hello world',
    }

    h->queue->add_job('mailer', $job)

=head2 SEE ALSO

L<LibreCat::Worker>

=cut
