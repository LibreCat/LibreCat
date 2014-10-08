package App::Catalog;

use Catmandu::Sane;
use Catmandu;
use Dancer ':syntax';
use Catmandu::Util qw(:array);

use App::Catalog::Helper;
use App::Catalog::Interface;

use App::Catalog::Route::admin;
use App::Catalog::Route::import;
use App::Catalog::Route::person;
use App::Catalog::Route::publication;
use App::Catalog::Route::search;

use Authentication::Authenticate;
use Dancer::Plugin::Auth::Tiny;
use Syntax::Keyword::Junction 'any' => { -as => 'any_of' };

# make variables with leading '_' visible in TT
$Template::Stash::PRIVATE = 0;

sub _authenticate {
    my ( $user, $pass ) = @_;
    my $user = h->getAccount( params->{user} )->[0];
    return 0 unless $user;

    my $verify = verifyUser( params->{user}, params->{pass} );
    if ( $verify and $verify ne "error" ) {
        return $user;
    }
    else {
        return 0;
    }
}

Dancer::Plugin::Auth::Tiny->extend(
    any_role => sub {
        my $coderef         = pop;
        my @requested_roles = @_;
        return sub {
            my @user_roles = @{ session("role") || [] };
            if ( any_of(@requested_roles) eq any_of(@user_roles) ) {
                goto $coderef;
            }
            else {
                redirect '/access_denied';
            }
        };
    },
    role => sub {
        my $coderef = pop;
        my $role    = shift;
        return sub {
            if ( $role eq session->{role} ) {
                goto $coderef;
            }
            else {
                redirect 'access_denied';
            }
        };
    },
);

get '/' => sub {
    my $params = params;

    if ( session->{role} eq "super_admin" ) {
        forward '/myPUB/search/admin', $params;
    }
    elsif ( session->{role} eq "reviewer" ) {
        forward '/myPUB/search/reviewer', $params;
    }
    elsif ( session->{role} eq "dataManager" ) {
        forward '/myPUB/search/datamanager', $params;
    }
    else {
        forward '/myPUB/search', $params;
    }
};

get '/login' => sub {
    my $data = { path => vars->{requested_path} };
    $data->{error_message} = params->{error_message} ||= '';
    $data->{login}         = params->{login}         ||= "";
    template 'login', $data;
};

post '/login' => sub {

    my $user = _authenticate( params->{user}, params->{pass} );

    if ($user) {
        session role => $user->{super_admin}
            || $user->{reviewer}
            || $user->{dataManager}
            || "user";
        session user         => $user->{login};
        session personNumber => $user->{_id};

        redirect params->{path} if params->{path};

        if ( session->{role} eq "super_admin" ) {
            redirect '/myPUB/search/admin';
        }
        elsif ( session->{role} eq "reviewer" ) {
            redirect '/myPUB/search/reviewer';
        }
        elsif ( session->{role} eq "dataManager" ) {
            redirect '/myPUB/search/datamanager';
        }
        else {
            redirect '/myPUB/search';
        }
    }
    else {
        forward '/myPUB/login',
            { error_message => "Wrong username or password!" },
            { method        => 'GET' };
    }
};

any '/logout' => sub {
    session->destroy;
    redirect '/myPUB/login';
};

# any '/access_denied' => sub {
#     return "acces denied";
# };

get '/change_role/:role' => needs login => sub {
    my $user = h->getAccount( session->{user} )->[0];

    # is user allowed to take this role?

    if ( params->{role} eq "reviewer" and $user->{reviewer} ) {
        session role => "reviewer";
    }
    elsif ( params->{role} eq "dataManager" and $user->{dataManager} ) {
        session role => "dataManager";
    }
    elsif ( params->{role} eq "admin" and $user->{super_admin} ) {
        session role => "super_admin";
    }
    else {
        session role => "user";
    }
    redirect '/myPUB';
};

1;
