package App::Catalogue::Route::search;

=head1 NAME

App::Catalog::Route::search

=cut

use Catmandu::Sane;
use Dancer qw/:syntax/;
use App::Helper;
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

=head2 PREFIX /librecat/search

All publication searches are handled within the prefix search.

=cut
prefix '/librecat/search' => sub {

=head2 GET /admin

Performs search for admin.

=cut
    get '/admin' => needs role => 'super_admin' => sub {

        my $p = h->extract_params();
        $p->{facets} = h->default_facets();
        # foda: Bielefeld specific!!
        $p->{facets}->{foda} = { terms => { field => 'foda', size => 1 } };
        push @{$p->{q}}, "status=public" if $p->{fmt} and $p->{fmt} eq "autocomplete";

        my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = h->search_publication($p);

        $hits->{style} = $sort_style->{style};
        $hits->{sort} = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus} = "admin";

        if ($p->{fmt} ne 'html') {
        	h->export_publication($hits, $p->{fmt});
        } else {
        	template "home", $hits;
        }

    };

=head2 GET /reviewer

Performs search for reviewer.

=cut

    get '/reviewer' => needs role => "reviewer" => sub {
    	my $account = h->get_person(session->{user});
		redirect "/librecat/search/reviewer/$account->{reviewer}->[0]->{_id}";
    };
    
    get '/reviewer/:department_id' => needs role => 'reviewer' => sub {

        my $p = h->extract_params();
        my $id = session 'personNumber';
        my $account = h->get_person(session->{user});
        my $dep_query = "department=" . params->{department_id};
        push @{$p->{q}}, $dep_query;

        $p->{facets} = h->default_facets();
        my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};
        push @{$p->{q}}, "status=public" if $p->{fmt} and $p->{fmt} eq "autocomplete";

        my $hits = h->search_publication($p);
        $hits->{style} = $sort_style->{style};
        $hits->{sort} = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus} = "reviewer_" . params->{department_id};
        $hits->{department_id} = params->{department_id};

        if ($p->{fmt} ne 'html') {
            h->export_publication($hits, $p->{fmt});
        } else {
            template "home", $hits;
        }

    };

=head2 GET /datamanager

Performs search for data manager.

=cut
    get '/data_manager' => needs role => 'data_manager' => sub {
    	my $account = h->get_person(session->{user});
    	redirect "/librecat/search/data_manager/$account->{data_manager}->[0]->{_id}";
    };
    
    get '/data_manager/:department_id' => needs role => 'data_manager' => sub {

        my $p = h->extract_params();
        my $id = session 'personNumber';
        my $account = h->get_person(session->{user});
        my $dep_query = "department=" . params->{department_id};
        push @{$p->{q}}, "(type=researchData OR type=dara)";
        push @{$p->{q}}, $dep_query;
        push @{$p->{q}}, "status=public" if $p->{fmt} and $p->{fmt} eq "autocomplete";

        $p->{facets} = h->default_facets();
        my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        my $hits = h->search_publication($p);
        $hits->{style} = $sort_style->{style};
        $hits->{sort} = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus} = "data_manager_" . params->{department_id};
        $hits->{department_id} = params->{department_id};

        if ($p->{fmt} ne 'html') {
            h->export_publication($hits, $p->{fmt});
        } else {
            template "home", $hits;
        }

    };

=head2 GET '/delegate'

Takes first request after login or change_role and redirects
according to first delegate ID.

=cut
	get '/delegate' => needs role => "delegate" => sub {
		my $account = h->get_person(session->{user});
		if(params->{fmt} and params->{fmt} eq "autocomplete"){
			my $p = h->extract_params();
			push @{$p->{q}}, "status=public";
			foreach my $delegate (@{$account->{delegate}}){
				push @{$p->{q}}, $delegate;
			}
			my $hits = h->search_publication($p);
			h->export_publication($hits, params->{fmt});
		}
		else {
			redirect "/librecat/search/delegate/$account->{delegate}->[0]";
		}
	};

=head2 GET '/delegate/:delegate_id'

Performs a search of records for delegated person's
publications.

=cut
    get '/delegate/:delegate_id' => needs role => "delegate" => sub {
        my $p = h->extract_params();
        my $id = params->{delegate_id};
        push @{$p->{q}}, "(person=$id OR creator=$id)";
        push @{$p->{q}}, "status=public" if $p->{fmt} and $p->{fmt} eq "autocomplete";

        $p->{facets} = h->default_facets;
        my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '', $id);
        $p->{sort} = $sort_style->{sort_backend};

        # override default author/editor facet
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
        $hits->{style} = $sort_style->{style};
        $hits->{sort} = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus} = "delegate_".$id;
        $hits->{delegate_id} = $id;

        if ($p->{fmt} ne 'html') {
            h->export_publication($hits, $p->{fmt});
        } else {
            template "home", $hits;
        }

    };

=head2 GET /

Performs search for user.

=cut
    get '/' => needs login => sub {

        my $p = h->extract_params();
        my $id = session 'personNumber';
        my @orig_q = @{$p->{q}};

        push @{$p->{q}}, "(person=$id OR creator=$id)";
        push @{$p->{q}}, "type<>researchData";
        push @{$p->{q}}, "type<>dara";
        push @{$p->{q}}, "status=public" if $p->{fmt} and $p->{fmt} eq "autocomplete";

        $p->{facets} = h->default_facets();
        my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        # override default author/editor facet
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

        my $researchhits;
        @{$p->{q}} = @orig_q;
        push @{$p->{q}}, "(person=$id OR creator=$id)";
        push @{$p->{q}}, "(type=researchData OR type=dara)";
        push @{$p->{q}}, "status=public" if $p->{fmt} and $p->{fmt} eq "autocomplete";
        $researchhits = h->search_publication($p);
        $hits->{researchhits} = $researchhits if $researchhits;

        $hits->{style} = $sort_style->{style};
        $hits->{sort} = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus} = "user";

        if ($p->{fmt} ne 'html') {
            h->export_publication($hits, $p->{fmt});
        } else {
            template "home", $hits;
        }

    };

    get '/data' => sub {
    	my $p = h->extract_params();
        my $id = session 'personNumber';
        my @orig_q = @{$p->{q}};

        push @{$p->{q}}, "(person=$id OR creator=$id)";
        push @{$p->{q}}, "(type=researchData OR type=dara)";
        push @{$p->{q}}, "status=public" if $p->{fmt} and $p->{fmt} eq "autocomplete";

        $p->{facets} = h->default_facets();
        my $sort_style = h->get_sort_style( $p->{sort} || '', $p->{style} || '');
        $p->{sort} = $sort_style->{sort_backend};

        # override default author/editor facet
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

        my $researchhits;
        @{$p->{q}} = @orig_q;
        push @{$p->{q}}, "(person=$id OR creator=$id)";
        push @{$p->{q}}, "(type=researchData OR type=dara)";
        $researchhits = h->search_publication($p);
        $hits->{researchhits} = $researchhits if $researchhits;

        $hits->{style} = $sort_style->{style};
        $hits->{sort} = $p->{sort};
        $hits->{user_settings} = $sort_style;
        $hits->{modus} = "data";

        if ($p->{fmt} ne 'html') {
            h->export_publication($hits, $p->{fmt});
        } else {
            template "home", $hits;
        }

    };
};

1;
