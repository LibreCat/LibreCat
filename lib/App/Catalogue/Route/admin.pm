package App::Catalogue::Route::admin;

=head1 NAME

App::Catalogue::Route::admin - Route handler for admin actions

=cut

use Catmandu::Sane;
use Catmandu::Util qw(trim);
use Dancer ':syntax';
use App::Helper;
use App::Catalogue::Controller::Importer;
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

=head1 PREFIX /myPUB/admin

Permission: for admins only. Every other user will get a 403.

=cut
prefix '/myPUB/admin' => sub {

=head2 GET /account

Prints a search form for the authority database.

=cut
    get '/account' => needs role => 'super_admin' => sub {
        template 'admin/account';
    };

=head2 GET /account/new

Opens an empty form. The ID is automatically generated.

=cut
    get '/account/new' => needs role => 'super_admin' => sub {
        template 'admin/forms/edit_account',
            { _id => h->new_record('researcher') };
    };

=head2 GET /account/search

Searches the authority database. Prints the search form + result list.

=cut
    get '/account/search' => needs role => 'super_admin' => sub {
        my $p = params;

        $p->{q} = h->string_array($p->{q});
        my $hits = h->search_researcher($p);
        template 'admin/account', $hits;
    };

=head2 GET /account/edit/:id

Opens the record with ID id. Cancel returns to /account.
Save does a POST on /account/update.

=cut
    get '/account/edit/:id' => needs role => 'super_admin' => sub {
        my $person = h->researcher->get(params->{id});
        template 'admin/forms/edit_account', $person;
    };

=head2 POST /account/update

Saves the data in the authority database.

=cut
    post '/account/update' => needs role => 'super_admin' => sub {
        my $p = params;

        $p = h->nested_params($p);

        h->update_record('researcher', $p);
        template 'admin/account';
    };

=head2 GET /account/import

Input is person id. Returns warning if person is already in the database.

=cut
    get '/account/import' => needs role => 'super_admin' => sub {
        my $id = trim params->{id};

        my $person_in_db = h->researcher->get($id);
        if ($person_in_db) {
            template 'admin/account',
                { error => "There is already an account with ID $id." };
        }
        else {
            my $p = App::Catalogue::Controller::Importer->new(
    			id => $id,
    			source => 'bis',
    			)->fetch;
            template 'admin/forms/edit_account', $p;
        }
    };

    get '/project' => needs role => 'super_admin' => sub {
    	my $hits = h->search_project({q => "", limit => 100, start => params->{start} || 0});
        template 'admin/project', $hits;
    };

    get '/project/new' => needs role => 'super_admin' => sub {
        template 'admin/project/edit_project',
            { _id => h->new_record('project') };
    };

    get '/project/search' => sub {
        my $p = h->extract_params();

        my $hits = h->search_project($p);

        template 'admin/project', $hits;
    };

    get '/project/edit/:id' => needs role => 'super_admin' => sub {
        my $project = h->project->get(params->{id});
        template 'admin/forms/edit_project', $project;
    };

    post '/project/update' => needs role => 'super_admin' => sub {
        my $p = h->nested_params();
    	my $return = h->update_record('project', $p);
    	redirect '/myPUB/admin/project';
    };
    
    get '/research_group' => needs role => 'super_admin' => sub {
    	my $hits = h->search_research_group({q => "", limit => 100, start => params->{start} || 0});
        template 'admin/research_group', $hits;
    };

    get '/research_group/new' => needs role => 'super_admin' => sub {
        template 'admin/research_group/edit_research_group',
            { _id => h->new_record('research_group') };
    };

    get '/research_group/search' => sub {
        my $p = h->extract_params();

        my $hits = h->search_research_group($p);

        template 'admin/research_group', $hits;
    };

    get '/research_group/edit/:id' => needs role => 'super_admin' => sub {
        my $research_group = h->research_group->get(params->{id});
        template 'admin/forms/edit_research_group', $research_group;
    };

    post '/research_group/update' => needs role => 'super_admin' => sub {
        my $p = h->nested_params();
    	my $return = h->update_record('research_group', $p);
    	redirect '/myPUB/admin/research_group';
    };
    
    
    
    get '/department' => needs role => 'super_admin' => sub {
    	my $hits = h->search_department({q => "", limit => 100, start => params->{start} || 0});
        template 'admin/department', $hits;
    };

    get '/department/new' => needs role => 'super_admin' => sub {
        template 'admin/department/edit_department',
            { _id => h->new_record('department') };
    };

    get '/department/search' => sub {
        my $p = h->extract_params();

        my $hits = h->search_department($p);

        template 'admin/department', $hits;
    };

    get '/department/edit/:id' => needs role => 'super_admin' => sub {
        my $department = h->department->get(params->{id});
        template 'admin/forms/edit_department', $department;
    };

    post '/department/update' => needs role => 'super_admin' => sub {
        my $p = h->nested_params();
    	my $return = h->update_record('department', $p);
    	redirect '/myPUB/admin/department';
    };
    
    
    

    get '/award' => needs role => 'super_admin' => sub {
    	my $hits = h->search_award({q => "rectype=record", limit => 1000});
    	my $preis = h->search_award({q => "rectype=preis", limit => 1000});
    	my $auszeichnung = h->search_award({q => "rectype=auszeichnung", limit => 1000});
    	my $akademie = h->search_award({q => "rectype=akademie", limit => 1000});

    	$hits->{preis} = $preis->{hits};
        $hits->{auszeichnung} = $auszeichnung->{hits};
        $hits->{akademie} = $akademie->{hits};
        
    	template 'admin/award', $hits;
    };

    get '/award/edit/:id' => needs role => 'super_admin' => sub {
    	my $id = param 'id';
    	my $hits = h->get_award($id);
    	my $award = h->search_award({q => "rectype<>record", limit => 1000});
    	$hits->{award} = $award->{hits};

    	template 'admin/forms/edit_award', $hits;
    };

    get '/award/new/record' => needs role => 'super_admin' => sub {
    	my $hits;
    	my $award = h->search_award({q => "rectype<>record", limit => 1000});
       	my $ids = h->award->to_array;
    	my @newIds;
    	foreach (@$ids){
    		$_->{_id} =~ s/^AW//g;
    		push @newIds, $_->{_id};
    	}
    	@newIds = sort {$a <=> $b} @newIds;
    	my $idsLength = @newIds;
    	my $createdid = $newIds[$idsLength-1];
    	$createdid++;

    	$hits->{_id} = "AW" . $createdid;
    	$hits->{rec_type} = "record";
    	$hits->{award} = $award->{hits};
    	$hits->{"new"} = 1;

    	template 'admin/forms/edit_award', $hits;
    };

    get '/award/new/award' => needs role => 'super_admin' => sub {
    	my $hits;
       	my $ids = h->award->to_array;
    	my @newIds;
    	foreach (@$ids){
    		$_->{_id} =~ s/^AW//g;
    		push @newIds, $_->{_id};
    	}
    	@newIds = sort {$a <=> $b} @newIds;
    	my $idsLength = @newIds;
    	my $createdid = $newIds[$idsLength-1];
    	$createdid++;

    	$hits->{_id} = "AW" . $createdid;
    	$hits->{rec_type} = "preis";
    	$hits->{"new"} = 1;

    	template 'admin/forms/edit_award', $hits;
    };

    post '/award/update' => needs role => 'super_admin' => sub {
    	my $p = h->nested_params();
    	my $return = h->update_record('award', $p);
    	return to_dumper $return;
    };

};

1;
