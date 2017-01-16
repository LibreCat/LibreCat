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

    my $id          = $data->{_id}     // '<new>';
    my $record_type = $data->{type}    // '<unknown>';
    my $user_id     = $data->{user_id} // '<unknown>';
    my $person      = h->get_person($user_id);
    my $login       = $person->{login};

    h->queue->add_job('audit',{
        id      => $id ,
        bag     => 'publication' ,
        process => "hook($name)" ,
        action  => "$type" ,
        message => "activated by $login ($user_id)" ,
    });

    $data;
}

1;
