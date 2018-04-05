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

librecat url check [options] <FILE> [OUTFILE]

options:

    --importer=<...>
    --exporter=<...>

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    (['importer=s', ""], ['exporter=s', ""],);
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

    $self->app->set_global_options(
        {importer => $opts->importer, exporter => $opts->exporter,});

    if ($cmd eq 'check') {
        return $self->_check(@$args);
    }
}

sub _check {
    my ($self, $file, $out_file) = @_;

    croak "usage: $0 check <FILE>" unless defined($file) && -r $file;

    my $importer
        = $self->app->global_options->{importer}
        ? Catmandu->importer($self->app->global_options->{importer})
        : Catmandu->importer(
        'TSV',
        file   => $file,
        fields => [qw(_id url)],
        header => 0
        );

    my %exporter_opts = (fields => [qw(_id url http_status)], header => 0);
    $exporter_opts{file} = $out_file if $out_file;

    my $exporter
        = $self->app->global_options->{exporter}
        ? Catmandu->exporter($self->app->global_options->{exporter})
        : Catmandu->exporter('TSV', %exporter_opts);

    my $cv = AnyEvent->condvar;

    my $records = $importer->each(
        sub {
            my $rec = $_[0];

            my $id  = $rec->{_id} // '<undef>';
            my $url = $rec->{url};

            unless ($id && $url) {
                print STDERR "$id : need a url\n";
                return;
            }

            $cv->begin;

            http_head $url, sub {
                my ($body, $hdr) = @_;
                $exporter->add(
                    {_id => $id, url => $url, http_status => $hdr->{Status}});

                $cv->end;
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

    librecat url check [options] <FILE> [OUTFILE]

    options:

        --importer=<...>
        --exporter=<...>

    E.g.

    librecat url check test.tsv

    with test.tsv as:

        1  http://www.google.com
        2  http://www.microsoft.com

=head1 commands

=head2 check <FILE> [OUTFILE]

Given an input file with a TAB delimited list of ID and URL pairs,
this comnmand will follow all URLs for their HTTP response. The output
will have the HTTP status code added.

Optional provide an C<importer> or C<exporter> name for other types
of input. Required fields for other inputs are C<_id> and C<url>

=cut
