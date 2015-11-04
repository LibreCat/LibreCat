=head1 NAME

LibreCat::Worker::Mailer - a worker for sending mails

=head1 SYNOPSIS

    use LibreCat::Worker::Mailer;

    my $mailer = LibreCat::Worker::Mailer->new(
        to => 'me',
        from => 'system_mailer',
        subject => 'important',
        body => 'hello world',
        );

    $mailer->do_work();

=cut

package LibreCat::Worker::Mailer;

use Catmandu::Sane;
use Moo;
use Email::Sender::Simple qw(sendmail);
use Try::Tiny;

with 'LibreCat::Worker';

has to => (is => 'ro', required => 1);
has from => (is => 'ro', required => 1);
has body => (is => 'ro', required => 1);
has mailer => (is => 'lazy');

sub _build_mailer {
    my ($self) = @_;

    Email::Simple->create(
        header => [
            To => $self->to,
            From => $self->from,
            Subject => $self->subject,
        ],
        body => $self->body,
    );
}

sub do_work {
    my ($self) = @_;

    try {
        $self->log->debug("sending mail to $self->to");
        sendmail($self->mailer);
        $self->log->debug("send mail successfully to $self->to");
    } catch {
        $self->log->error("send mail error: $_");
    }
}

1;
