package LibreCat::Cmd::queue;

use Catmandu::Sane;
use Catmandu;
use Net::Telnet::Gearman;

use parent 'LibreCat::Cmd';

sub description { 
    return <<EOF;
Usage:

librecat queue

EOF
}

sub command {
    my ($self, $opts, $args) = @_;

    my $gm = Net::Telnet::Gearman->new(
        Host => '127.0.0.1',
        Port => 4730,
    );
    my $status = "";
    $status .= "Server version: ".$gm->version."\n";
    $status .= "Workers:\n";
    $status .= Catmandu->export_to_string(
        [map { +{
            fd        => $_->file_descriptor,
            ip        => $_->ip_address,
            id        => $_->client_id,
            functions => join(",", @{$_->functions}),
        } } $gm->workers],
        'Table',
        fields => 'fd,ip,id,functions',
    );
    $status .= "Status:\n";
    $status .= Catmandu->export_to_string(
        [map { +{
            function => $_->name,
            queued   => $_->queue,
            busy     => $_->busy,
            free     => $_->free,
            running  => $_->running,
        } } $gm->status],
        'Table',
        fields => 'function,queued,busy,free,running',
    );
    say $status;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::queue - show job queue status

=cut
