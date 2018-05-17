package LibreCat::Hook::audit_message;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Catmandu;
use Moo;

has name => (is => 'ro', default => sub {''});
has type => (is => 'ro', default => sub {''});

sub fix {
    my ($self, $data) = @_;

    my $name = $self->name;
    my $type = $self->type;

    h->log->debug("entering audit_message() hook from : $name ($type)");

    unless ($name =~ /^(publication|import)/) {
        h->log->debug("only handling publication|import hooks");
        return $data;
    }

    my $id      = $data->{_id}     // '<new>';
    my $user_id = $data->{user_id} // '<unknown>';
    my $login   = '<unknown>';

    if (defined $data->{user_id}) {
        my $person = h->get_person($user_id);
        $login = $person->{login} if $person;
    }

    my $action;

    if (request && request->path_info()) {
        $action = request->path_info();
    }
    else {
        $action = 'batch';
    }

    my $job = {
        id      => $id,
        bag     => 'publication',
        process => "hook($name)",
        action  => "$action",
        message => "activated by $login ($user_id)",
    };

    h->log->debug("adding job: " . to_yaml($job));
    try {
        h->queue->add_job('audit', $job);
    }
    catch {
        h->log->trace("caught a : $_");
    };

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::audit_message - a hook to submit audit messages

=head1 SYNPOSIS

    # in your config
    audit: 1

    hooks:
      publication-update:
        before_fixes:
         - audit_message

=cut
