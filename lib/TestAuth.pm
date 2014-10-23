package TestAuth;

use Catmandu::Sane;
use Catmandu;
use Dancer ':syntax';
use Catmandu::Util qw(:array);

use App::Catalog::Helper;
#use App::Catalog::Interface;

# use App::Catalog::Route::admin;
# use App::Catalog::Route::import;
# use App::Catalog::Route::person;
# use App::Catalog::Route::publication;
# use App::Catalog::Route::search;

use Authentication::Authenticate;
use Dancer::Plugin::Auth::Tiny;
use Syntax::Keyword::Junction 'any' => { -as => 'any_of' };

# make variables with leading '_' visible in TT
$Template::Stash::PRIVATE = 0;

sub _authenticate {
    my ( $login, $pass ) = @_;
    my $user = h->getAccount( $login )->[0];
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
        session->{role} ? return sub {
            if ( any_of(@requested_roles) eq session->{role} {
                goto $coderef;
            }
            else {
                redirect '/access_denied';
            }
        } : redirect '/login';
    },
    role => sub {
        my ($role, $coderef) = @_;
        session->{role} ? return sub {
            if ( session->{role} && $role eq session->{role} ) {
                goto $coderef;
            }
            else {
                redirect '/access_denied';
            }
        } : redirect '/login';
    },
);

get '/' => sub {
    return "This is home.";
};

get '/login' => sub {
    my $data = { return_url => params->{return_url} };
    $data->{error_message} = params->{error_message} ||= '';
    $data->{login}         = params->{login}         ||= "";
    template 'login', $data;
};

post '/login' => sub {

    my $user = _authenticate( params->{user}, params->{pass} );

    if ($user) {
        my $super_admin = "super_admin" if $user->{super_admin};
        my $reviewer = "reviewer" if $user->{reviewer};
        my $dataManager = "dataManager" if $user->{dataManager};
        session role => $super_admin || $reviewer || $dataManager || "user";
        session user         => $user->{login};
        session personNumber => $user->{_id};

        redirect params->{return_url} if params->{return_url};
        redirect '/';
    }
    else {
        forward '/login',
            { error_message => "Wrong username or password!" },
            { method        => 'GET' };
    }
};

any '/logout' => sub {
    session->destroy;
    redirect '/login';
};

get '/open' => sub {
    return "You don't need to log in.";
};

get '/private' => needs login => sub {
    return "You're logged in.";
};

get '/admin' => needs role => 'super_admin' => sub {
    return "You're admin.";
};

get '/reviewer' => needs any_role => qw/admin reviewer/ => sub {
    return "You're reviewer or admin.";
};

any '/access_denied' => sub {
    return "Access denied.";
};

get '/test/session' => sub {
    return to_dumper session;
}

1;
