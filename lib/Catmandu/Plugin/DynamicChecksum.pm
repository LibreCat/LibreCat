package Catmandu::Plugin::DynamicChecksum;

use Moo::Role;
use Digest::MD5;
use IO::Handle::Util;
use namespace::clean;

with 'Catmandu::Logger';

sub BUILD {
    my ($self) = @_;

    return if $self->does('Catmandu::FileBag::Index');

    # Insert a Catmandu::FileStore 'files' method into Catmandu::Store-s
    unless ($self->can('checksum')) {
        my $stash = Package::Stash->new(ref $self);
        $stash->add_symbol(
            '&checksum' => sub {
                my ($self, $id) = @_;

                $self->log->debug("calculating checksum for $id");

                my $file = $self->get($id);

                unless ($file) {
                    $self->log->error("no file found for $id");
                }

                return Catmandu::Plugin::DynamicChecksum::dynamic_checksum($self,$file);
            }
        );
    }
}

sub dynamic_checksum {
    my ($files,$file) = @_;

    my $md5 = Digest::MD5->new;

    my $io  = IO::Handle::Util::io_prototype write => sub {
            my $self = shift;
            $md5->add(@_);
        },
        syswrite => sub {
            my $self = shift;
            $md5->add(@_);
        },
        close => sub {
            my $self = shift;
        };

    $files->stream($io,$file);

    $io->close;

    return $md5->hexdigest;
}

1;

__END__

=pod

=head1 NAME

Catmandu::Plugin::DynamicChecksum - Adds a checksum method to FileStores to (re)calculate checksums

=head1 SYNOPSIS

    # In files.yml
    default: &filestore_settings
        package: Simple
        options:
            default_plugins: [ 'DynamicChecksum' ]
            root: data/file_uploads

    # Now the file_stores can (re)calculate the checksum of files

    my $files = $file_store->index->files($key);

    my $file     = $files->get("myfile.pdf");
    my $checksum = $files->checksum("myfile.pdf");

    unless ($file->{md5} eq $checksum) {
        print STDERR "Error, checksums don't match";
    }

=cut
