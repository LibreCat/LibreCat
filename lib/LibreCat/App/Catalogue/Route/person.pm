package LibreCat::App::Catalogue::Route::person;

=head1 NAME

LibreCat::App::Catalogue::Route::person - handles person settings

=cut

use Catmandu::Sane;
use LibreCat qw(user);
use Catmandu::Util qw(:array);
use Dancer qw(:syntax);
use LibreCat::App::Helper;

=head1 PREFIX /librecat/person

All person settings are handled within the prefix '/person'.

=cut

prefix '/librecat/person' => sub {

=head2 GET /preference

User edits the preferred citation style and sorting
for his own publication list.

=cut

    get '/preference/:delegate_id' => sub {
        my $qparams = params("query");
        my $rparams = params("route");
        my $params = +{};
        my $current_style = h->current_style;
        $params->{delegate_id} = $rparams->{delegate_id};
        $params->{style} = $current_style if defined $current_style;
        $params->{'sort'} = $qparams->{'sort'} if $qparams->{'sort'};
        forward '/librecat/person/preference', $params;
    };

    get '/preference' => sub {
        my $qparams = params("query");
        my $person
            = h->get_person($qparams->{delegate_id} || session('user_id'));
        my $sort;
        my $tmp;
        if ($qparams->{'sort'}) {
            if (ref $qparams->{'sort'} ne "ARRAY") {
                $sort = [$qparams->{sort}];
            }
            else {
                $sort = $qparams->{sort};
            }

            foreach my $s (@$sort) {
                if ($s =~ /(\w{1,})\.(asc|desc)/) {
                    push @{$tmp->{'sort'}}, $s;
                }
            }
            $person->{'sort'} = $tmp->{'sort'};
        }
        else {
            $person->{'sort'} = undef;
        }

        my $current_style = h->current_style;
        if (defined($current_style)) {
            $person->{style} = $current_style;
        }
        else {
            $person->{style} = undef;
        }

        user->add($person);

        redirect uri_for('/librecat');
    };

=head2 POST /author_id

User adds author identifiers to db (e.g. ORCID). These will
be displayed on author's profile page.

=cut

    post '/author_id' => sub {

        my $id         = params->{_id};
        my $person     = h->get_person($id) || {_id => $id};
        my @identifier = keys %{h->config->{lists}->{author_id}};

        map {$person->{$_} = params->{$_} ? params->{$_} : ""} @identifier;
        redirect uri_for('/librecat') if scalar(keys %{$person}) > 1;

        user->add($person);

    };

=head2 POST /set_language

User can choose default language for the librecat backend
"en" -> English - default
"de" -> German

=cut

    get '/set_language' => sub {

        my $h = h();
        my $person = $h->current_user;
        my $lang   = param('lang');
        if ( $h->locale_exists( $lang ) ) {
            if( $person ){
                $person->{lang} = $lang;
                user->add($person);
            }
            $h->set_locale( $lang );
        }

        redirect uri_for('/librecat');

    };

=head1 POST /affiliation

User edits his affiliation. Will be displayed if you opens
new publication form.

=cut

    post '/affiliation' => sub {

        my $fix = Catmandu::Fix->new(
            fixes => ['compact("department")', 'vacuum()']);

        my $p = params;
        $p = h->nested_params($p);
        $fix->fix($p);
        my $person = h->current_user;
        if( $person ){
            $person->{department} = $p->{department} // [];
            user->add($person);
        }

        redirect uri_for('/librecat');

    };

};

1;
