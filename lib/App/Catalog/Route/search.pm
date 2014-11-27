package App::Catalog::Route::search;

=head1 NAME

    App::Catalog::Route::search

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;
use App::Catalog::Controller::Search qw/search_publication/;
use Dancer::Plugin::Auth::Tiny;

Dancer::Plugin::Auth::Tiny->extend(
    role => sub {
        my ($role, $coderef) = @_;
          return sub {
            if ( session->{role} && $role eq session->{role} ) {
                goto $coderef;
            }
            else {
                redirect '/access_denied';
            }
          }
        }
);

=head2 PREFIX /myPUB/search

    All publication searches are handled within the
    prefix search.

=cut
prefix '/myPUB/search' => sub {

=head2 GET /admin

    Performs search for admin.

=cut
    get '/admin' => needs role => 'super_admin' => sub {

        my $p = h->extract_params();
        $p->{facets} = h->default_facets();

        my $hits = h->search_publication($p);
        $hits->{modus} = "admin";
        template "home", $hits;

    };

=head2 GET /reviewer

    Performs search for reviewer.

=cut
    get '/reviewer' => needs role => 'reviewer' => sub {

        my $p = h->extract_params();
        $p->{facets} = h->default_facets();

        my $hits = h->search_publication($p);
        $hits->{modus} = "reviewer";
        template "home", $hits;

    };

=head2 GET /datamanager

    Performs search for data manager.

=cut
    get '/datamanager' => needs role => 'dataManager' => sub {

        my $p = h->extract_params();
        $p->{facets} = h->default_facets();

        my $hits = h->search_publication($p);
        $hits->{modus} = "data_manager";
        template "home", $hits;

    };

=head2 GET '/delegate/:delegate_id'

    Performs a search of records for delegated person's
    publications.

=cut
    get '/delegate/:delegate_id' => sub {
        my $p = h->extract_params();

        my $hits = h->search_publication($p);
        $hits->{modus} = "delegate_".$p->{delegate_id};
        template "home", $hits;
    };

=head2 GET /

    Performs search for user.

=cut
    get '/' => needs login => sub {

        my $p = h->extract_params();
        my $id = session 'personNumber';
        $p->{facets} = h->default_facets();

        # override default author/editor facette
        $p->{facets}->{author} = {
            terms => {
                field   => 'author.id',
                size    => 20,
                exclude => [$id]
            }
        };
        $p->{facets}->{editor} = {
            terms => {
                field   => 'editor.id',
                size    => 20,
                exclude => [$id]
            }
        };

        my $hits = h->search_publication($p);
        $hits->{modus} = "user";
        template "home", $hits;

    };

};

1;
