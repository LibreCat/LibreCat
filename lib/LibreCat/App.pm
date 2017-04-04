package LibreCat::App;

=head1 NAME

LibreCat::App - a webapp that runs an awesome institutional repository.

=cut

use Catmandu::Sane;

our $VERSION = '0.01';

use Catmandu::Util;
use LibreCat;

use Dancer qw(:syntax);

use LibreCat::App::Search;       # the frontend
use LibreCat::App::Catalogue;    # the backend
use LibreCat::App::Api;          # the api

use LibreCat::App::Helper;
use Dancer::Plugin::Auth::Tiny;
use Dancer::Plugin::DirectoryView;

# make variables with leading '_' visible in TT,
# otherwise they are considered private
$Template::Stash::PRIVATE = 0;

hook before => sub {
    my $method    = request->method;
    my $path_info = request->path_info;
    my $conf      = h->config->{permissions};
    my $routes    = $conf->{routes} // [];

    my $login_route    = _login_route($conf);
    my $redirect_route = _redirect_route($conf);
    my $role_route     = _role_route($conf);
    my $api_route      = _api_route($conf);

    for my $route (@$routes) {
        my ($_method,$_regex,$_role,$_params) = @$route;

        next unless $_method eq 'ANY' || $_method eq $method;
        next unless $path_info =~ /^${_regex}/;

        if ($_role eq 'login') {
            $login_route->($_params);
        }
        elsif ($_role eq 'redirect') {
            $redirect_route->($_params);
        }
        elsif ($_role eq 'role') {
            $role_route->($_params);
        }
        elsif ($_role eq 'api_access') {
            $api_route->($_params);
        }
        else {
            # ok no login needed
        }
    }
};

sub _login_route {
    my $conf = shift;
    sub {
        if ( session $conf->{logged_in_key} ) {
            # ok
        }
        else {
             my $query_params = params("query");
             my $data =
               { $conf->{callback_key} => uri_for( request->path, $query_params ) };
             for my $k ( @{ $conf->{passthrough} } ) {
               $data->{$k} = params->{$k} if params->{$k};
             }
             return redirect uri_for( $conf->{login_route}, $data );
        }
    };
}

sub _redirect_route {
    my $conf = shift;
    sub {
        my $url = shift;
        return redirect $url ;
    };
}

sub _role_route {
    my $conf = shift;
    sub {
        my $role = shift;
        if ( session $conf->{logged_in_key} ) {
            if (session->{role} && $role eq session->{role}) {
                # ok
            }
            else {
                return redirect uri_for('/access_denied');
            }
        }
        else {
             my $query_params = params("query");
             my $data =
               { $conf->{callback_key} => uri_for( request->path, $query_params ) };
             for my $k ( @{ $conf->{passthrough} } ) {
               $data->{$k} = params->{$k} if params->{$k};
             }
             return redirect uri_for( $conf->{login_route}, $data );
        }
    };
}

sub _api_route {
    my $conf = shift;
    sub {
        my $role = shift // '';
        if (_ip_match(request->address)) {
            # ok
        }
        elsif (session->{role} && $role eq session->{role}) {
            # ok
        }
        else {
            return return redirect uri_for('/access_denied');
        }
    };
}

sub _ip_match {
    my $ip        = shift;
    my $access    = h->config->{filestore}->{api}->{access} // {};
    my $ip_ranges = $access->{ip_ranges} // [];

    h->within_ip_range($ip,$ip_ranges);
}

# custom authenticate routine
sub _authenticate {
    my ($username, $password) = @_;

    # Clean dirties .. in loginname
    $username =~ s{[^a-zA-Z0-9_]*}{}mg;

    my $auth = do {
        my $package_name = Catmandu->config->{authentication}->{package};
        my $package_opts = Catmandu->config->{authentication}->{options} // {};

        if ($package_name) {
            my $pkg = Catmandu::Util::require_package($package_name);

            if ($pkg) {
                $pkg->new($package_opts);
            }
            else {
                h->log->error("failed to create a new $package_name authenticator");
                undef;
            }
        }
        else {
            h->log->error('No authentication.package defined');
            h->log->error('Did you create a catmandu.local.yml?');
            undef;
        }
    };

    return unless $auth;

    my $user = LibreCat->user->find_by_username($username) || return;

    $auth->authenticate({username => $username, password => $password})
        || return;

    $user;
}

=head2 GET /login

Route the user will be sent to if login is required.

=cut

get '/login' => sub {

    # what are you doing? you're already in.
    redirect '/librecat' if session('user');

    # not logged in yet
    template 'login',
        {
        error_message => params->{error_message} || '',
        login         => params->{login}         || '',
        return_url    => params->{return_url}    || '',
        lang          => session->{lang}         || h->config->{default_lang}
        };
};

=head2 POST /login

Route where login data is sent to. On success redirects to
'/librecat' or to the path requested before

=cut

post '/login' => sub {
    my $user = _authenticate(params->{user}, params->{pass});
    my $return_url = params->{return_url} || '/librecat';

    # Deleting bad urls to external websites
    $return_url =~ s{^[a-zA-Z:]+(\/\/)[^\/]+}{};

    if ($user) {
        my $super_admin = "super_admin" if $user->{super_admin};
        my $reviewer    = "reviewer"    if $user->{reviewer};
        my $project_reviewer = "project_reviewer"
            if $user->{project_reviewer};
        my $data_manager = "data_manager" if $user->{data_manager};
        my $delegate     = "delegate"     if $user->{delegate};
        session role => $super_admin
            || $reviewer
            || $project_reviewer
            || $data_manager
            || $delegate
            || "user";
        session user         => $user->{login};
        session personNumber => $user->{_id};
        session lang         => $user->{lang} || h->config->{default_lang};

        redirect uri_for($return_url);
    }
    else {
        forward '/login', {error_message => 'Wrong username or password!'},
            {method => 'GET'};
    }
};

=head2 ANY /logout

The logout route. Destroys session.

=cut

any '/logout' => sub {

    session role         => undef;
    session user         => undef;
    session personNumber => undef;

    redirect '/';
};

=head2 GET /set_language

Route to call when changing language in session

=cut

get '/set_language' => sub {
    my $referer = request->{referer};
    session lang => params->{lang};
    $referer =~ s/lang=\w{2}\&*//g;
    redirect $referer;
};

=head2 ANY /access_denied

User sees this one if access is denied.

=cut

any '/access_denied' => sub {
    status '403';
    template '403';
};

any '/coffee' => sub {
    status '418';
    template '418';
};

=head1 ANY {other route....}

Throws 'page not found'.

=cut

any qr{.*} => sub {
    if (session->{user}) {
        return redirect uri_for('/librecat');
    } else {
        status 'not_found';
        return template '404';
    }
};

1;
