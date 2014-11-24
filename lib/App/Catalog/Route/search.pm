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

        my $p = params;
        push @{$p->{q}}, "year>1950";
        $p = h->extract_params($p);

        $p->{facets} = {
            author => {
                terms => {
                    field   => 'author.id',
                    size    => 20,
                }
            },
            editor => {
                terms => {
                    field   => 'editor.id',
                    size    => 20,
                }
            },
            year => { terms => { field => 'year'} },
            type => { terms => { field => 'type', size => 20 } },
            open_access => { terms => { field => 'file.open_access', size => 1 } },
            quality_controlled => { terms => { field => 'quality_controlled', size => 1 } },
            popular_science => { terms => { field => 'popular_science', size => 1 } },
            extern => { terms => { field => 'extern', size => 1 } },
            status => { terms => { field => 'status', size => 5 } },
        };

        my $hits = h->search_publication($p);
        $hits->{modus} = "admin";
        template "home", $hits;

    };

=head2 GET /reviewer

    Performs search for reviewer.

=cut
    get '/reviewer' => needs role => 'reviewer' => sub {

        my $p = params;
        return to_dumper $p;
        # $p->{facets} = {
        #     coAuthor => {
        #         terms => {
        #             field   => 'author.id',
        #             size    => 20,
        #         }
        #     },
        #     coEditor => {
        #         terms => {
        #             field   => 'editor.id',
        #             size    => 20,
        #         }
        #     },
        #     open_access => { terms => { field => 'file.open_access', size => 1 } },
        #     quality_controlled => { terms => { field => 'quality_controlled', size => 1 } },
        #     popular_science => { terms => { field => 'popular_science', size => 1 } },
        #     extern => { terms => { field => 'extern', size => 1 } },
        #     status => { terms => { field => 'status', size => 5 } },
        # };

        my $hits = h->search_publication($p);
        $hits->{modus} = "reviewer";
        template "home", $hits;

    };

=head2 GET /datamanager

    Performs search for data manager.

=cut
    get '/datamanager' => needs role => 'dataManager' => sub {

        my $p = params;
        return to_dumper $p;
        # $p->{facets} = {
        #     coAuthor => {
        #         terms => {
        #             field   => 'author.id',
        #             size    => 20,
        #         }
        #     },
        #     coEditor => {
        #         terms => {
        #             field   => 'editor.id',
        #             size    => 20,
        #         }
        #     },
        #     open_access => { terms => { field => 'file.open_access', size => 1 } },
        #     quality_controlled => { terms => { field => 'quality_controlled', size => 1 } },
        #     popular_science => { terms => { field => 'popular_science', size => 1 } },
        #     extern => { terms => { field => 'extern', size => 1 } },
        #     status => { terms => { field => 'status', size => 5 } },
        # };

        my $hits = h->search_publication($p);
        $hits->{modus} = "data_manager";
        template "home", $hits;

    };

=head2 GET '/delegate/:delegate_id'

    Performs a search of records for delegated person's
    publications.

=cut
    get '/delegate/:delegate_id' => sub {
        my $p = params;
        return to_dumper $p;
        #$params->{modus} = "delegate_".$params->{delegate_id};
        #search_publication($params);
    };

=head2 GET /

    Performs search for user.

=cut
    get '/' => needs login => sub {

        my $p = h->extract_params(params);
        return to_dumper $p;
        # my $id = session 'personNumber';
        # $p->{facets} = {
        #     coAuthor => {
        #         terms => {
        #             field   => 'author.id',
        #             size    => 20,
        #             exclude => [$id]
        #         }
        #     },
        #     coEditor => {
        #         terms => {
        #             field   => 'editor.id',
        #             size    => 20,
        #             exclude => [$id]
        #         }
        #     },
        #     open_access => { terms => { field => 'file.open_access', size => 1 } },
        #     quality_controlled => { terms => { field => 'quality_controlled', size => 1 } },
        #     popular_science => { terms => { field => 'popular_science', size => 1 } },
        #     extern => { terms => { field => 'extern', size => 1 } },
        #     status => { terms => { field => 'status', size => 5 } },
        # };

        my $hits = h->search_publication($p);
        $hits->{modus} = "user";
        template "home", $hits;

    };

};

1;
