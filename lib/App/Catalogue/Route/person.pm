package App::Catalogue::Route::person;

=head1 NAME

App::Catalogue::Route::person - handles person settings

=cut

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use Dancer qw(:syntax);
use App::Helper;
use Dancer::Plugin::Auth::Tiny;

=head1 PREFIX /librecat/person

All person settings are handled within the prefix '/person'.

=cut
prefix '/librecat/person' => sub {

=head2 GET /preference

User edits the preferred citation style and sorting
for his own publication list.

=cut
    get '/preference/:delegate_id' => needs role => 'delegate' => sub {
    	my $params;
    	$params->{delegate_id} = params->{delegate_id};
    	$params->{style} = params->{style} if params->{style};
    	$params->{'sort'} = params->{'sort'} if params->{'sort'};
    	forward '/librecat/person/preference', $params;
    };
    
    get '/preference' => needs login => sub {
        my $person = h->get_person( params->{delegate_id} || session('personNumber') );
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

        h->update_record('researcher', $person);

        redirect '/librecat';
    };

=head2 POST /author_id

User adds author identifiers to db (e.g. ORCID). These will
be displayed on author's profile page.

=cut
    post '/author_id' => needs login => sub {

        my $id = params->{_id};
        my $person = h->get_person( $id ) || {_id => $id};
        my @identifier = keys %{h->config->{lists}->{author_id}};

        map { $person->{$_} = params->{$_} ? params->{$_} : "" } @identifier;
        redirect '/librecat' if keys %{$person} > 1;

        my $result = h->update_record('researcher', $person);

        redirect '/librecat';

    };

=head2 POST /edit_mode

User can choose default edit mode for editing publications.
"normal" -> edit form with tabs
"expert" -> one long edit form

=cut
    post '/edit_mode' => needs login => sub {

        my $person = h->get_person( session('personNumber') );
        my $mode = params->{edit_mode};
        if($mode eq "normal" or $mode eq "expert"){
        	$person->{edit_mode} = $mode;
        	h->update_record('researcher', $person);
        }

        redirect '/librecat';

    };

=head2 POST /set_language

User can choose default language for the librecat backend
"en" -> English - default
"de" -> German

=cut
    get '/set_language' => needs login => sub {

        my $person = h->get_person( session('personNumber') );
        my $lang = params->{lang};
        if($lang eq "en" or $lang eq "de"){
        	$person->{lang} = $lang;
        	h->update_record('researcher', $person);
        	session lang => $lang;
        }

        redirect '/librecat';

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
        my $person = h->get_person( session('personNumber') );
        $person->{department} = $p->{department};
        h->update_record('researcher', $person);

        redirect '/librecat';

    };

};

1;
