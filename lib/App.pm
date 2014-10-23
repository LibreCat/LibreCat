package App;

=head1 NAME

    App - a webapp that runs an institutional repository

=cut

our $VERSION = '0.01';

use Catmandu::Sane;
use Dancer ':syntax';

use App::Catalog::Helper;

use Authentication::Authenticate;
use Dancer::Plugin::Auth::Tiny;
use Syntax::Keyword::Junction 'any' => { -as => 'any_of' };

# make variables with leading '_' visible in TT
$Template::Stash::PRIVATE = 0;

load_app 'App::Catalog', prefix => 'myPUB';

# custom authenticate routine
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

# extending, 'cause we need roles
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

=head2 GET /login

    Route the user will be sent to if login is required.

=cut
get '/login' => sub {
    my $data = { return_url => params->{return_url} };
    $data->{error_message} = params->{error_message} ||= '';
    $data->{login}         = params->{login}         ||= "";
    template 'login', $data;
};

=head2 POST /login

    Route where login data is sent to. On sucess redirects to
    '/' or to the path requested before

=cut
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

=head2 ANY /logout

    The logout route. Destroys session.

=cut
any '/logout' => sub {
    session->destroy;
    redirect '/login';
};

=head2 ANY /access_denied

    User sees this one if access is denied.

=cut
any '/access_denied' => sub {
    # add an really ugly
    return "Access denied.";
};

#####################################
# some test routes
#####################################

get '/test/home' => sub {
    return "This is home.";
};

get '/test/open' => sub {
    return "You don't need to log in.";
};

get '/test/private' => needs login => sub {
    return "You're logged in.";
};

get '/test/admin' => needs role => 'super_admin' => sub {
    return "You're admin.";
};

get '/test/reviewer' => needs any_role => qw/admin reviewer/ => sub {
    return "You're reviewer or admin.";
};

1;
