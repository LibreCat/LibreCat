package LibreCat::App::Catalogue::Route::audit;

=head1 NAME

LibreCat::App::Catalogue::Route::audit - controller for handling audit messages

=cut

use Catmandu::Sane;
use Catmandu::Util;
use Dancer ':syntax';
use Dancer::Serializer::Mutable qw(template_or_serialize);
use LibreCat::App::Helper;
use POSIX qw(strftime);
use LibreCat::Audit;
use URL::Encode qw(url_decode);

=head2 PREFIX /librecat/audit

All publication searches are handled within the prefix search.

=cut

prefix '/librecat' => sub {

=head2 GET /audit/:bag/:id

List all audit messages for an :id in the store :bag

=cut

    get '/audit/:bag/:id' => sub {

        unless (h->config->{audit}) {
            status 403;
            return template 'error',
                {message => "Not allowed: audit is not activated."};
        }

        my $bag = params("route")->{bag};
        my $id  = params("route")->{id};

        my $it =
            audit()->select( bag => $bag )->select( id => $id )
            ->sorted(
            sub {
                $_[0]->{time} <=> $_[1]->{time};
            }
        )->map(
            sub {
                $_[0]->{date} = strftime("%Y-%m-%dT%H:%M:%SZ",
                    gmtime($_[0]->{time} // 0));
                $_[0];
            }
        );

        my $array = $it->to_array;

        template_or_serialize 'backend/audit', {audit => $array};
    };

    post '/audit/:bag/:id' => sub {

        unless (h->config->{audit}) {
            status 403;
            return template 'error',
                {message => "Not allowed: audit is not activated."};
        }

        my $bag = params("route")->{bag};
        my $id  = params("route")->{id};

        my $user_id = session->{user_id} // '<unknown>';
        my $action  = params->{action};
        my $message = params->{message};
        my $login   = '<unknown>';

        if (my $person = h->current_user) {
            $login = $person->{login};
        }

        unless ($action) {
            content_type 'json';
            status '406';
            return to_json {error => "Parameter action is missing."};
        }

        unless ($message) {
            $message = "activated by $login ($user_id)";
        }

        my $ar = audit()->add({
            id      => $id,
            bag     => $bag,
            process => 'LibreCat::App::Catalogue::Route::audit',
            action  => $action,
            message => $message,
        });

        unless($ar){
            #is not supposed to fail as all attributes are given
            content_type 'json';
            status 500;
            return to_json({ error => "unexpected error" });
        }

        return to_json({ _id => $ar->{_id} });
    };
};

sub audit {

    state $s = LibreCat::Audit->new();

}

1;
