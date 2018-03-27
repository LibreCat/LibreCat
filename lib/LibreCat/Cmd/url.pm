package LibreCat::Cmd::url;

use Catmandu::Sane;
use Catmandu;
use AnyEvent;
use AnyEvent::HTTP;
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat url check <FILE> [OUTFILE]

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/(check)/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    binmode(STDOUT, ":encoding(utf-8)");

    if ($cmd eq 'check') {
        return $self->_check(@$args);
    }
}

sub _check {
    my ($self, $file, $out_file) = @_;

    croak "usage: $0 check <FILE>" unless defined($file) && -r $file;

    my $importer = Catmandu->importer('YAML', file => $file);
    my $exporter;

    if (defined $out_file) {
        $exporter = Catmandu->exporter('YAML', file => $out_file);
    }

    my $cv = AnyEvent->condvar;

    my $records = $importer->each(
        sub {
            my $rec = $_[0];

            $cv->begin;
            if (defined $rec->{url}) {
                http_head $rec->{url}, sub {
                    my ($body, $hdr) = @_;
                    if ($exporter) {
                        $exporter->add(
                            {
                                _id         => $rec->{_id},
                                url         => $rec->{url},
                                http_status => $hdr->{Status}
                            }
                        );
                    }
                    else {
                        printf "%s\t%s\t%s\n", $rec->{_id}, $hdr->{Status},
                            $rec->{url};
                    }
                    $cv->end;
                    }
            }
        }
    );

    $cv->recv;

    return 0;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::url - check urls

=head1 SYNOPSIS

    librecat schemas url check <FILE> [OUTFILE]

=head1 commands

=head2 check <FILE> [OUTFILE]

Check all provided URLs. <FILE> must be a valid YAML file with '_id' and 'url' fields.

This command returns a YAML formatted output file if [OUTFILE] is provided or a tabs-separated list to STDOUT.

=cut
