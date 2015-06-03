package App::Catalogue::Route::person;

=head1 NAME

App::Catalogue::Route::person - handles person settings

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer ':syntax';
use App::Helper;
use App::Catalogue::Controller::Admin qw(:person);
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
        my $person = h->researcher->get( session('personNumber') );
        #my $tmp = h->get_sort_style(params->{sort} || '', params->{style} || '');
        my $sort; my $tmp;
        if(params->{'sort'}){
        	if(ref params->{'sort'} ne "ARRAY"){
        		$sort = [params->{sort}];
        	}
        	else{
        		$sort = params->{sort};
        	}

        	foreach my $s (@$sort){
        		if($s =~ /(\w{1,})\.(asc|desc)/){
        			push @{$tmp->{'sort'}}, $s;
        		}
        	}
        	$person->{'sort'} = $tmp->{'sort'};
        }
        else {
        	$person->{'sort'} = undef;
        }

        if(params->{style}){
        	$person->{style} = params->{style} if array_includes(h->config->{lists}->{styles},params->{style});
        }
        else {
        	$person->{style} = undef;
        }

#return to_dumper $person;
        h->researcher->add($person);
        h->researcher->commit;

        redirect '/myPUB';
    };

=head2 POST /author_id

User adds author identifiers to db (e.g. ORCID). These will
be displayed on author's profile page.

=cut
    post '/author_id' => needs login => sub {

        my $id = params->{_id};
        my $person = h->researcher->get( $id ) || {_id => $id};
        my @identifier = keys %{h->config->{lists}->{author_id}};

        map { $person->{$_} = params->{$_} ? params->{$_} : "" } @identifier;
        redirect '/myPUB' if keys %{$person} > 1;

        my $result = update_person($person);

        redirect '/myPUB';

    };

=head2 POST /edit_mode

User can choose default edit mode for editing publications.
"normal" -> edit form with tabs
"expert" -> one long edit form

=cut
    post '/edit_mode' => sub {

        my $person     = h->researcher->get( session('personNumber') );
        my $type = params->{edit_mode};
        if($type eq "normal" or $type eq "expert"){
        	$person->{edit_mode} = $type;
        	h->researcher->add($person);
        	h->researcher->commit;
        }

        redirect '/myPUB';

    };

=head1 POST /affiliation

User edits his affiliation. Will be displayed if you opens
new publication form.

=cut
    post '/affiliation' => needs login => sub {

    	my $fix = Catmandu::Fix->new(
    	  fixes => [ 'compact_array("department")']
    	);

        my $p = params;
        $p = h->nested_params($p);
        $fix->fix($p);
        my $person = edit_person( session('personNumber') );
        $person->{department} = $p->{department};
        update_person($person);

        redirect '/myPUB';

    };

};

1;
