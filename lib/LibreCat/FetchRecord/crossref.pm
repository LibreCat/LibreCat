package LibreCat::FetchRecord::crossref;

use Catmandu::Util qw(:io :hash);
use Catmandu qw(importer);
use Furl;
use LibreCat -self;
use URI::Escape;
use Moo;

with 'LibreCat::FetchRecord';

has 'baseurl' =>
    (is => 'ro', default => sub {"https://api.crossref.org/works/"});

has 'furl' => (is => 'lazy');

sub _build_furl {
    Furl->new(
        agent => 'LibreCat/Importer 2.x',
        timeout => '10',
    );
}

sub fetch {
    my ($self, $id) = @_;

    # Clean up data
    $id =~ s{^\D+[:\/]}{};

    $self->log->debug("requesting $id from crossref");

    my $mail_to = librecat->config->{admin_email} // 'mail@librecat.org';
    my $url = sprintf "%s%s%s%s", $self->baseurl, uri_escape_utf8($id), '?mailto=', $mail_to;

    my $furl = $self->furl;
    my $res = $furl->get($url);

    my $data;
    if ($res->is_success) {
       my $content = $res->content;
       $data = Catmandu->importer("JSON", file => \$content)->to_array;
    }
    else {
        $self->log->error(
            "failed to request https://api.crossref.org/works/$id");
        return ();
    }

    my $fixer = librecat->fixer('crossref_mapping.fix');

    $data = $fixer->fix($data);

    $self->log->debugf("data: %s", $data);

    return $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::FetchRecord::crossref - Create a LibreCat publication based on a DOI

=head1 SYNOPSIS

    use LibreCat::FetchRecord::crossref;

    my $pub = LibreCat::FetchRecord::crossref->new->fetch('doi:10.1002/0470841559.ch1');

=cut
