package LibreCat::App::Catalogue::Route::message;

=head1 NAME LibreCat::App::Catalogue::Route::message

Route handler for messages.

=cut

use Catmandu::Sane;
use Dancer qw(:syntax);
use Dancer::Plugin::Ajax;
use LibreCat::Message;
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::Permission;

sub access_denied_hook {
    h->hook('message-access-denied')
        ->fix_around(
        {_id => params->{record_id}, user_id => session->{user_id},});
}

sub message {
    state $msg = LibreCat::Message->new();
}

ajax "/librecat/messages/unread/:record_id" => sub {
    my $record_id = params->{record_id};
    $record_id or pass;
    my $user_id   = session->{user_id};

    my $it = message->select(record_id => $record_id)->map(
        sub {
            unless (grep ($user_id, @{$_[0]->{read}})) {
                return $_[0];
            }
        }
    );

    return to_json({unread_msg => $it->count});
};

get "/librecat/message/:record_id" => sub {
    my $record_id = params->{record_id};

    $record_id or pass;

    my $user_id = session("user_id");

    unless (
        p->can_edit(
            $record_id,
            {
                user_id => $user_id,
                role    => session("role"),
                live    => 1
            }
        )
        )
    {
        access_denied_hook();
        status '403';
        forward '/access_denied', {referer => request->referer};
    }

    my $it = message->select(record_id => $record_id)->sorted(
        sub {
            $_[0]->{date_created} cmp $_[1]->{date_created};
        }
    )->map(
        sub {
            $_[0]->{user} = h->get_person($_[0]->{user_id})->{full_name};
            $_[0];
        }
    );

    # store information that logged-in user already read the message
    $it->each(sub {
        push $user_id, @{$_[0]->{read}} unless grep($user_id, @{$_[0]->{read});
        message->add($_[0]);
    });

    my $array = $it->to_array;

    to_json({message => $array});
};

post "/librecat/message" => sub {
    my $params = params;

    my $user_id   = session->{user_id};
    my $record_id = params->{record_id};
    my $message   = params->{message};

    unless (
        p->can_edit(
            $record_id,
            {user_id => $user_id, role => session("role"), live => 1}
        )
        )
    {
        access_denied_hook();
        status '403';
        forward '/access_denied';
    }

    unless ($message) {
        content_type 'json';
        status '406';
        return to_json {error => "Parameter message is missing."};
    }

    my $msg_rec = message->add(
        {record_id => $record_id, user_id => $user_id, message => $message});

    unless ($msg_rec) {

        # is not supposed to fail as all attributes are given
        content_type 'json';
        status 500;
        return to_json(
            {
                error => "unexpected errors: "
                    . join(' | ', @{message->last_errors()})
            }
        );

    }

    if ($params->{return_url}) {
        redirect $params->{return_url};
    }
    else {
        redirect "/librecat";
    }
};

1;
