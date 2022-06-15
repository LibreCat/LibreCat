package LibreCat::App::Catalogue::Route::search;

=head1 NAME

LibreCat::App::Catalog::Route::search

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:is);
use Dancer qw/:syntax/;
use LibreCat qw(searcher);
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::Permission;
use LibreCat::CQL::Util qw(:escape);

=head2 PREFIX /librecat/search

All publication searches are handled within the prefix search.

=cut

prefix '/librecat/search' => sub {

=head2 GET /admin

Performs search for admin.

=cut

    get '/admin' => sub {

        my $p = h->extract_params();

        my $hits;

        if (params->{similar_search}) {
            $hits = searcher->native_search(
                'publication',
                {
                    query => {
                        "bool" => {
                            "must" => {
                                "match" => {
                                    "title" => {
                                        "query"                => $p->{q},
                                        "minimum_should_match" => "70%"
                                    }
                                }
                            },
                            "must_not" => {"term" => {"status" => "deleted"}},
                            "should"   => {
                                "match_phrase" => {
                                    "title" =>
                                        {"query" => $p->{q}, "slop" => "50"}
                                }
                            }
                        }
                    },
                    limit => $p->{limit} ||= h->config->{default_page_size},
                    start => $p->{start} ||= 0,
                }
            );

            $hits->{modus} = "admin";
        }
        else {
            push @{$p->{cql}}, "status<>deleted";

            $p->{sort} = $p->{sort} // h->config->{default_sort_backend};
            $p->{facets} = h->config->{facets}->{publication};

            $hits = searcher->search('publication', $p);

            $hits->{modus} = "admin";
        }

        template "home", $hits;
    };

=head2 GET /reviewer

Performs search for reviewer.

=cut

    get '/reviewer' => sub {
        my $account = h->current_user() or forward("/access_denied");
        is_array_ref($account->{reviewer}) && scalar(@{ $account->{reviewer} }) or forward("/access_denied");
        redirect uri_for(
            "/librecat/search/reviewer/$account->{reviewer}->[0]->{_id}");
    };

    get '/reviewer/:department_id' => sub {

        my $p       = h->extract_params();
        my $account = h->current_user() or forward("/access_denied");
        my $department_id = params("route")->{department_id};

        # if user not reviewer or not allowed to access chosen department
        unless ($account->{reviewer}
            and grep {$department_id eq $_->{_id}}
            @{$account->{reviewer}})
        {
            forward("/access_denied");
        }

        push @{$p->{cql}}, "status<>deleted";
        $p->{sort} = $p->{sort} // h->config->{default_sort_backend};

        my $dep_query = "department=" . cql_escape($department_id);
        push @{$p->{cql}}, $dep_query;

        $p->{facets} = h->config->{facets}->{publication};

        my $hits = searcher->search('publication', $p);
        $hits->{modus}         = "reviewer_" . $department_id;
        $hits->{department_id} = $department_id;

        template "home", $hits;

    };

=head2 GET /reviewer

Performs search for reviewer.

=cut

    get '/project_reviewer' => sub {
        my $account = h->current_user() or forward("/access_denied");
        is_array_ref($account->{project_reviewer}) && scalar(@{ $account->{project_reviewer} }) or forward("/access_denied");
        redirect uri_for(
            "/librecat/search/project_reviewer/$account->{project_reviewer}->[0]->{_id}"
        );
    };

    get '/project_reviewer/:project_id' => sub {

        my $p       = h->extract_params();
        my $account = h->current_user() or forward("/access_denied");
        my $project_id = params("route")->{project_id};

        # if user not project_reviewer or not allowed to access chosen project
        unless ($account->{project_reviewer}
            and grep {$project_id eq $_->{_id}}
            @{$account->{project_reviewer}})
        {
            forward("/access_denied");
        }

        push @{$p->{cql}}, "status<>deleted";
        $p->{sort} = $p->{sort} // h->config->{default_sort_backend};

        my $dep_query = "project=" . cql_escape($project_id);
        push @{$p->{cql}}, $dep_query;

        $p->{facets} = h->config->{facets}->{publication};

        my $hits = searcher->search('publication', $p);
        $hits->{modus}      = "project_reviewer_" . $project_id;
        $hits->{project_id} = $project_id;

        template "home", $hits;

    };

=head2 GET /datamanager

Performs search for data manager.

=cut

    get '/data_manager' => sub {
        my $account = h->current_user() or forward("/access_denied");
        is_array_ref($account->{data_manager}) && scalar(@{$account->{data_manager}}) or forward("/access_denied");
        redirect uri_for(
            "/librecat/search/data_manager/$account->{data_manager}->[0]->{_id}"
        );
    };

    get '/data_manager/:department_id' => sub {
        my $p       = h->extract_params();
        my $account = h->current_user() or forward("/access_denied");
        my $department_id = params("route")->{department_id};

        # if user not data_manager or not allowed to access chosen department
        unless ($account->{data_manager}
            and grep {$department_id eq $_->{_id}}
            @{$account->{department}})
        {
            forward("/access_denied");
        }

        my $dep_query = "department=" . cql_escape($department_id);

        push @{$p->{cql}}, "status<>deleted";
        push @{$p->{cql}}, "type=research_data";
        push @{$p->{cql}}, $dep_query;
        $p->{sort} = $p->{sort} // h->config->{default_sort_backend};

        $p->{facets} = h->config->{facets}->{publication};

        my $hits = searcher->search('publication', $p);
        $hits->{modus}         = "data_manager_" . $department_id;
        $hits->{department_id} = $department_id;

        template "home", $hits;

    };

=head2 GET '/delegate'

Takes first request after login or change_role and redirects
according to first delegate ID.

=cut

    get '/delegate' => sub {
        my $account = h->current_user() or forward("/access_denied");
        is_array_ref($account->{delegate}) && scalar(@{$account->{delegate}}) or forward("/access_denied");
        redirect uri_for(
            "/librecat/search/delegate/$account->{delegate}->[0]");
    };

=head2 GET '/delegate/:delegate_id'

Performs a search of records for delegated person's
publications.

=cut

    get '/delegate/:delegate_id' => sub {
        my $p  = h->extract_params();
        my $id = params("route")->{delegate_id};
        my $escaped_id = cql_escape( $id );

        my $account = h->current_user() or forward("/access_denied");

        # if user not delegate or not allowed to access chosen delegate_id
        unless ($account->{delegate}
            and grep {$id eq $_}
            @{$account->{delegate}})
        {
            forward("/access_denied");
        }

        my $perm_by_user_identity = p->all_author_types;

        my @type_query = ();
        for (@$perm_by_user_identity) {
            push @type_query , "$_=$escaped_id";
        }

        push @{$p->{cql}}, "(" . join(" OR ",@type_query) . ")";
        push @{$p->{cql}}, "status<>deleted";
        $p->{sort} = $p->{sort} // h->config->{default_sort_backend};

        $p->{facets} = h->config->{facets}->{publication};

        my $hits = searcher->search('publication', $p);
        $hits->{modus}       = "delegate_" . $id;
        $hits->{delegate_id} = $id;

        template "home", $hits;
    };

=head2 GET /

Performs search for user.

=cut

    get '/' => sub {
        my $p  = h->extract_params();
        my $account = h->current_user() or forward("/access_denied");
        my $id = $account->{_id};
        my $escaped_id = cql_escape( $id );

        my $perm_by_user_identity = p->all_author_types;

        my @type_query = ();
        for (@$perm_by_user_identity) {
            push @type_query , "$_=$escaped_id";
        }

        push @{$p->{cql}}, "(" . join(" OR ",@type_query) . ")";
        push @{$p->{cql}}, "status<>deleted";
        push @{$p->{cql}}, "status=public"
            if $p->{fmt} and $p->{fmt} eq "autocomplete";
        $p->{sort} = $p->{sort} // h->config->{default_sort_backend};

        $p->{facets} = h->config->{facets}->{publication};

        my $hits = searcher->search('publication', $p);

        $hits->{modus} = "user";

        template "home", $hits;
    };

};

1;
