package App::Catalog::Route::person;

=head1 NAME

    App::Catalog::Route::person - handles person settings

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use App::Catalog::Helper;
use App::Catalog::Controller::Admin qw/:person/;
use Dancer::Plugin::Auth::Tiny;

=head1 PREFIX /myPUB/person

    All person settings are handled within the prefix '/person'.

=cut
prefix '/myPUB/person' => sub {

=head2 GET /preference

    User edits the preferred citation style and sorting
    for his own publication list.

=cut
    get '/preference' => needs login => sub {

        my $person = h->getPerson( session('personNumber') );
        my $style;
        my $sort;
        if (    $person->{stylePreference}
            and $person->{stylePreference} =~ /(\w{1,})\.(\w{1,})/ )
        {
            if ( array_includes( h->config->{lists}->{styles}, $1 ) ) {
                $style = $1 unless $1 eq "pub";
            }
            $sort = $2;
        }
        elsif ( $person->{stylePreference}
            and $person->{stylePreference} !~ /\w{1,}\.\w{1,}/ )
        {
            if (array_includes(
                    h->config->{lists}->{styles},
                    $person->{stylePreference}
                )
                )
            {
                $style = $person->{stylePreference}
                    unless $person->{stylePreference} eq "pub";
            }
        }

        if ( $person->{sortPreference} ) {
            $sort = $person->{sortPreference};
        }

        $person->{stylePreference}
            = params->{style}
            || $style
            || h->config->{store}->{default_fd_style};
        $person->{sortPreference} = params->{'sort'} || $sort || "desc";

        h->authority_user->add($person);

        redirect '/myPUB';
    };

=head2 POST /author_id

    User adds author identifiers to db (e.g. ORCID). These will
    be displayed on author's profile page.

=cut
    post '/author_id' => needs login => sub {

        my $person     = h->authority_user->get( params->{_id} );
        my @identifier = keys h->config->{lists}->{author_id};

        map { $person->{$_} = params->{$_} ? params->{$_} : "" } @identifier;

        my $bag = h->authority_user->add($person);

        redirect '/myPUB';

    };

=head1 POST /affiliation

    User edits his affiliation. Will be displayed if you opens
    new publication form.

=cut
    post '/affiliation' => needs login => sub {

        my $p = params;
        $p = h->nested_params($p);
        my $person = edit_person( session('personNumber') );
        $person->{department} = $p->{department};
        update_person($person);

        redirect '/myPUB';

    };

};

1;
