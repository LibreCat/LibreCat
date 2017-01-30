package LibreCat::App::Catalogue::Route::search;

=head1 NAME

LibreCat::App::Catalog::Route::search

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use LibreCat::App::Helper;
use Dancer::Plugin::Auth::Tiny;

Dancer::Plugin::Auth::Tiny->extend(
    role => sub {
        my ($role, $coderef) = @_;
        return sub {
            if (session->{role} && $role eq session->{role}) {
                goto $coderef;
            }
            else {
                redirect '/access_denied';
            }
        }
    }
);

=head2 PREFIX /librecat/search

All publication searches are handled within the prefix search.

=cut

prefix '/librecat/search' => sub {

=head2 GET /admin

Performs search for admin.

=cut

    get '/admin' => needs role => 'super_admin' => sub {

        my $p = h->extract_params();

        push @{$p->{cql}}, "status<>deleted";

        my $sort_style
            = h->get_sort_style($p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = LibreCat->searcher->search('publication', $p);

        $hits->{style}         = $sort_style->{style};
        $hits->{sort}          = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus}         = "admin";

        template "home", $hits;
    };

=head2 GET /admin/similar_search

Performs search for similar titles, admin only

=cut

    get '/admin/similar_search' => needs role => 'super_admin' => sub {

        my $p = h->extract_params();

        unless ($p->{q} and ref $p->{q} eq "ARRAY" and $p->{q}->[0]) {
            return redirect '/librecat';
        }

        push @{$p->{cql}}, "status<>deleted";

        my $sort_style
            = h->get_sort_style($p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = h->publication->search(
            query => {
                "bool" => {
                    "must" => {
                        "match" => {
                            "title" => {
                                "query"                => $p->{q}->[0],
                                "minimum_should_match" => "70%"
                            }
                        }
                    },
                    "should" => {
                        "match_phrase" => {
                            "title" =>
                                {"query" => $p->{q}->[0], "slop" => "50"}
                        }
                    }
                }
            },
            limit => $p->{limit} ||= h->config->{default_page_size},
            start => $p->{start} ||= 0,
        );

        $hits->{style}         = $sort_style->{style};
        $hits->{sort}          = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus}         = "admin";

        template "home", $hits;

    };

=head2 GET /reviewer

Performs search for reviewer.

=cut

    get '/reviewer' => needs role => "reviewer" => sub {
        my $account = h->get_person(session->{user});
        redirect "/librecat/search/reviewer/$account->{reviewer}->[0]->{_id}";
    };

    get '/reviewer/:department_id' => needs role => 'reviewer' => sub {

        my $p       = h->extract_params();
        my $id      = session 'personNumber';
        my $account = h->get_person(session->{user});

        # if user not reviewer or not allowed to access chosen department
        unless ($account->{reviewer}
            and grep {params->{department_id} eq $_->{_id}}
            @{$account->{reviewer}})
        {
            return redirect
                "/librecat/search/reviewer/$account->{reviewer}->[0]->{_id}";
        }

        push @{$p->{q}}, "status<>deleted";

        my $dep_query = "department=" . params->{department_id};
        push @{$p->{cql}}, $dep_query;

        my $sort_style
            = h->get_sort_style($p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = LibreCat->searcher->search('publication', $p);
        $hits->{style}         = $sort_style->{style};
        $hits->{sort}          = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus}         = "reviewer_" . params->{department_id};
        $hits->{department_id} = params->{department_id};

        template "home", $hits;

    };

=head2 GET /reviewer

Performs search for reviewer.

=cut

    get '/project_reviewer' => needs role => "project_reviewer" => sub {
        my $account = h->get_person(session->{user});
        redirect
            "/librecat/search/project_reviewer/$account->{project_reviewer}->[0]->{_id}";
    };

    get '/project_reviewer/:project_id' => needs role =>
        'project_reviewer'              => sub {

        my $p       = h->extract_params();
        my $id      = session 'personNumber';
        my $account = h->get_person(session->{user});

        # if user not project_reviewer or not allowed to access chosen project
        unless ($account->{project_reviewer}
            and grep {params->{project_id} eq $_->{_id}}
            @{$account->{project_reviewer}})
        {
            return redirect
                "/librecat/search/project_reviewer/$account->{project_reviewer}->[0]->{_id}";
        }

        push @{$p->{q}}, "status<>deleted";

        my $dep_query = "project=" . params->{project_id};
        push @{$p->{cql}}, $dep_query;

        my $sort_style
            = h->get_sort_style($p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = LibreCat->searcher->search('publication', $p);
        $hits->{style}         = $sort_style->{style};
        $hits->{sort}          = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus}         = "project_reviewer_" . params->{project_id};
        $hits->{project_id}    = params->{project_id};

        template "home", $hits;

        };

=head2 GET /datamanager

Performs search for data manager.

=cut

    get '/data_manager' => needs role => 'data_manager' => sub {
        my $account = h->get_person(session->{user});
        redirect
            "/librecat/search/data_manager/$account->{data_manager}->[0]->{_id}";
    };

    get '/data_manager/:department_id' => needs role => 'data_manager' =>
        sub {

        my $p         = h->extract_params();
        my $id        = session 'personNumber';
        my $account   = h->get_person(session->{user});
        my $dep_query = "department=" . params->{department_id};

        push @{$p->{cql}}, "(type=research_data OR type=data)";
        push @{$p->{cql}}, $dep_query;

        my $sort_style
            = h->get_sort_style($p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = LibreCat->searcher->search('publication', $p);
        $hits->{style}         = $sort_style->{style};
        $hits->{sort}          = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus}         = "data_manager_" . params->{department_id};
        $hits->{department_id} = params->{department_id};

        template "home", $hits;

        };

=head2 GET '/delegate'

Takes first request after login or change_role and redirects
according to first delegate ID.

=cut

    get '/delegate' => needs role => "delegate" => sub {
        my $account = h->get_person(session->{user});
        redirect "/librecat/search/delegate/$account->{delegate}->[0]";
    };

=head2 GET '/delegate/:delegate_id'

Performs a search of records for delegated person's
publications.

=cut

    get '/delegate/:delegate_id' => needs role => "delegate" => sub {
        my $p  = h->extract_params();
        my $id = params->{delegate_id};
        push @{$p->{cql}}, "(person=$id OR creator=$id)";

        my $sort_style
            = h->get_sort_style($p->{sort} || '', $p->{style} || '', $id);
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = LibreCat->searcher->search('publication', $p);
        $hits->{style}         = $sort_style->{style};
        $hits->{sort}          = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus}         = "delegate_" . $id;
        $hits->{delegate_id}   = $id;

        template "home", $hits;

    };

=head2 GET /

Performs search for user.

=cut

    get '/' => needs login => sub {

        my $p      = h->extract_params();
        my $id     = session 'personNumber';

        push @{$p->{cql}}, "(person=$id OR creator=$id)";
        push @{$p->{cql}}, "type<>research_data";
        push @{$p->{cql}}, "status=public"
            if $p->{fmt} and $p->{fmt} eq "autocomplete";

        my $sort_style
            = h->get_sort_style($p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = LibreCat->searcher->search('publication', $p);

        my $researchhits;
        push @{$p->{cql}}, "(person=$id OR creator=$id)";
        push @{$p->{cql}}, "type=research_data";

        $researchhits = LibreCat->searcher->search('publication', $p);
        $hits->{researchhits} = $researchhits if $researchhits;

        $hits->{style}         = $sort_style->{style};
        $hits->{sort}          = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus}         = "user";

        template "home", $hits;

    };

    get '/data' => sub {
        my $p      = h->extract_params();
        my $id     = session 'personNumber';
        my @orig_q = @{$p->{q}};

        push @{$p->{cql}}, "(person=$id OR creator=$id)";
        push @{$p->{cql}}, "(type=research_data OR type=data)";

        my $sort_style
            = h->get_sort_style($p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = LibreCat->searcher->search('publication', $p);

        my $researchhits;
        @{$p->{q}} = @orig_q;
        push @{$p->{cql}}, "(person=$id OR creator=$id)";
        push @{$p->{cql}}, "(type=research_data OR type=data)";
        $researchhits = LibreCat->searcher->search('publication', $p);
        $hits->{researchhits} = $researchhits if $researchhits;

        $hits->{style}         = $sort_style->{style};
        $hits->{sort}          = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus}         = "data";

        template "home", $hits;

    };
};

1;
