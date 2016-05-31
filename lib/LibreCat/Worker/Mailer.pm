package LibreCat::Worker::Mailer;

use Catmandu::Sane;
use Email::Sender::Simple qw(sendmail);
use Moo;
use namespace::clean;

with 'LibreCat::Worker';

# TODO return values
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
        $self->log->debug("send mail successfully to $opts->{to}");
    }
    catch {
        $self->log->error("send mail error: $_");
    };

    return;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Worker::Mailer - a worker for sending mails

=head1 SYNOPSIS

    use LibreCat::Worker::Mailer;

    my $mailer = LibreCat::Worker::Mailer->new;
    $mailer->work({
        to => 'me',
        from => 'system_mailer',
        subject => 'important',
        body => 'hello world',
    });

=cut

