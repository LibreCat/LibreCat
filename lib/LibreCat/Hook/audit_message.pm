package LibreCat::Hook::audit_message;

# Code to submit audit messages (if configured)

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Catmandu;
use Moo;

has name => (is => 'ro', default => sub { '' });
has type => (is => 'ro', default => sub { '' });

sub fix {
    my ($self, $data) = @_;

    my $name = $self->name;
    my $type = $self->type;

    h->log->debug("entering audit_message() hook from : $name ($type)");
    h->log->debug(to_yaml($data));

    unless ($name =~ /^(publication|import)/) {
        h->log->debug("only handling publication|import hooks");
        return $data;
    }

    my $id          = $data->{_id}     // '<new>';
    my $user_id     = $data->{user_id} // '<unknown>';
    my $login       = '<unknown>';

    if (defined $data->{user_id}) {
        my $person   = h->get_person($user_id);
        $login       = $person->{login} if $person;
    }

    my $action;

    if (request && request->{path}) {
        $action = request->{path};
    }
    else {
        $action = 'batch';
    }

    try {
        h->queue->add_job('audit',{
            id      => $id ,
            bag     => 'publication' ,
            process => "hook($name)" ,
            action  => "$action" ,
            message => "activated by $login ($user_id)" ,
        });
    } catch {
        h->log->trace("caught a : $_");
    };

    $data;
}

1;
