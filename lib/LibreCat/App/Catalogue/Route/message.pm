package LibreCat::App::Catalogue::Route::message;

=head1 NAME LibreCat::App::Catalogue::Route::message

Route handler for messages.

=cut

use Catmandu::Sane;
use Dancer qw(:syntax);
use LibreCat qw(message);
use LibreCat::App::Helper;
use POSIX qw(strftime);

get "/librecat/message/:record_id" => sub {
    my $record_id = params->{record_id};

    $record_id or pass;

    my $it = message->select( record_id => $record_id )->sorted(
            sub {
                $_[0]->{time} <=> $_[1]->{time};
            }
        )->map(
            sub {
                $_[0]->{date} = strftime("%Y-%m-%dT%H:%M:%SZ",
                    gmtime($_[0]->{time} // 0));
                $_[0]->{user} = h->get_person($_[0]->{user_id})->{full_name};
                $_[0];
            }
        );

    my $array = $it->to_array;

    to_json({message => $array});
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

    redirect "/librecat";
};

1;
