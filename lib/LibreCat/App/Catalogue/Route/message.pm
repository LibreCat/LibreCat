package LibreCat::App::Catalogue::Route::message;

=head1 NAME LibreCat::App::Catalogue::Route::message

Route handler for messages.

=cut

use Catmandu::Sane;
use LibreCat qw(message);

# use Catmandu::Fix qw(expand);
use Dancer qw(:syntax);

get "/librecat/message/:record_id" => sub {
    my $msg = librecat->message->select(record_id => params->{record_id})
        // [];
    return to_json($msg);
};

post "/librecat/message" => sub {
    my $params = params;

    my $user_id   = session->{user_id};
    my $record_id = params->{record_id};
    my $message   = params->{new_message};

    unless ($message) {
        content_type 'json';
        status '406';
        return to_json {error => "Parameter message is missing."};
    }

    my $msg_rec = message->add(
        {record_id => $record_id, user_id => $user_id, message => $message,});

    unless ($msg_rec) {

        #is not supposed to fail as all attributes are given
        content_type 'json';
        status 500;
        return to_json(
            {
                error => "unexpected errors: "
                    . join(' | ', @{message->last_errors()})
            }
        );

    }

    # return to_json({ _id => $msg_recr->{_id} });
    redirect "/librecat";
};

1;
