package App;

=head1 NAME

    App - a webapp that runs an awesome institutional repository.

=cut

our $VERSION = '0.01';

use Catmandu::Sane;
use Dancer ':syntax';

use App::Catalogue; # the backend
use App::Search; # the frontend

use App::Helper;
use Authentication::Authenticate;
use Dancer::Plugin::Auth::Tiny;

# make variables with leading '_' visible in TT
$Template::Stash::PRIVATE = 0;

# custom authenticate routine
sub _authenticate {
    my ( $login, $pass ) = @_;
    my $user = h->getAccount( $login )->[0];
    return 0 unless $user;

    if (!$user->{account_type} or ($user->{account_type} and $user->{account_type} ne 'external')) {
        my $verify = verifyUser( params->{user}, params->{pass} );
        if ( $verify and $verify ne "error" ) {
            return $user;
        }
    } elsif ($user->{password} eq params->{pass}) {
        return $user;
    }
    return 0;
}

=head2 GET /login

    Route the user will be sent to if login is required.

=cut
get '/login' => sub {
    my $data;
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
        my $data_manager = "data_manager" if $user->{data_manager};
        my $delegate = "delegate" if $user->{delegate};
        session role => $super_admin || $reviewer || $data_manager || $delegate || "user";
        session user         => $user->{login};
        session personNumber => $user->{_id};

        redirect '/myPUB';
    }
    else {
        forward '/login',
            {error_message => 'Wrong username or password!'},
            {method => 'GET'};
    }
};

=head2 ANY /logout

    The logout route. Destroys session.

=cut
any '/logout' => sub {
    session->destroy;
    #forward '/login', {method => 'GET'};
    redirect '/';
};

=head2 ANY /access_denied

    User sees this one if access is denied.

=cut
any '/access_denied' => sub {
    # add an really ugly 403 page ;-)
    return status '403';#"Access denied.";
};

1;
