package LibreCat::App;

=head1 NAME

LibreCat::App - a webapp that runs an awesome institutional repository.

=cut

use Catmandu::Sane;
use Catmandu::Util;
use LibreCat qw(user);
use Dancer qw(:syntax);
use LibreCat::App::Search;       # the frontend
use LibreCat::App::Catalogue;    # the backend
use LibreCat::App::Api;          # the api
use LibreCat::App::Helper;
use Dancer::Plugin::Auth::Tiny;

our $VERSION = '0.01';

# make variables with leading '_' visible in TT,
# otherwise they are considered private
$Template::Stash::PRIVATE = 0;

hook before => sub {
    my $method    = request->method;
    my $path_info = request->path_info;
    my $conf      = h->config->{permissions};
    my $routes    = $conf->{routes} // [];

    my $handlers = {
        login      => _login_route($conf),
        redirect   => _redirect_route($conf),
        role       => _role_route($conf),
        no_access  => sub {
            return redirect uri_for('/access_denied');
        },
        default => sub { },
    };

    for my $h (keys %{$conf->{handlers}}) {
        next if $h =~ m{^(login|redirect|role|no_access|default)$};
        my $package_name = $conf->{handlers}->{$h};

        h->log->info("loading $package_name for $h");
        my $pkg = Catmandu::Util::require_package($package_name);

        if ($pkg) {
            $handlers->{$h} = $pkg->new()->route($conf);
        }
        else {
            h->log->error("failed to create a new $package_name permission");
            $handlers->{$h} = sub { };
        }
    }

    for my $route (@$routes) {
        my ($_method, $_regex, $_handler, @_handler_params) = @$route;

        $_handler = 'default' unless defined($_handler) && $_handler =~ /\S+/;

        next unless $_method eq 'ANY' || $_method eq $method;
        next unless $path_info =~ /^${_regex}/;

        if (my $h = $handlers->{$_handler}) {
            h->log->info("executing handler $_handler for $_regex");
            $h->(@_handler_params);
            last;
        }
        else {
            h->log->error("no handler found for $_handler");
        }
    }
};

hook before => sub {

    # conditionally reloads session based on timestamp
    # also load current user record into memory. see h->current_user
    h->maybe_reload_session();

};

hook before_template_render => sub {

    my $tokens = $_[0];

    #params in TT is hash resulted from call to "params()"
    $tokens->{params_query} = params("query");
    $tokens->{params_body} = params("body");
    $tokens->{params_route} = params("route");

};

sub _login_route {
    my $conf = shift;
    sub {
        if (session $conf->{logged_in_key}) {
            h->log->debug("found a logged_in_key in the session");
        }
        else {
            h->log->debug("not logged in redirecting to login page");
            my $query_params = params("query");
            my $data
                = {$conf->{callback_key} =>
                    uri_for(request->path_info, $query_params)
                };
            for my $k (@{$conf->{passthrough}}) {
                $data->{$k} = params->{$k} if params->{$k};
            }
            return redirect uri_for($conf->{login_route}, $data);
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
        my (@roles) = @_;
        my $role = session->{role};
        if (session $conf->{logged_in_key}) {
            if (session->{role} && grep(/^$role$/,@roles)) {
                # ok
            }
            else {
                return redirect uri_for('/access_denied');
            }
        }
        else {
            my $query_params = params("query");
            my $data
                = {$conf->{callback_key} =>
                    uri_for(request->path_info, $query_params)
                };
            for my $k (@{$conf->{passthrough}}) {
                $data->{$k} = params->{$k} if params->{$k};
            }
            return redirect uri_for($conf->{login_route}, $data);
        }
    };
}

# custom authenticate routine
sub _authenticate {
    my ($username, $password) = @_;

    # Clean dirties .. in loginname
    $username =~ s{[^a-zA-Z0-9_-]*}{}mg;

    my $auth = do {
        my $package_name = Catmandu->config->{authentication}->{package};
        my $package_opts = Catmandu->config->{authentication}->{options}
            // {};

        if ($package_name) {
            my $pkg = Catmandu::Util::require_package($package_name);

            if ($pkg) {
                $pkg->new($package_opts);
            }
            else {
                h->log->error(
                    "failed to create a new $package_name authenticator");
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

    my $user = user->find_by_username($username) || return;

    $auth->authenticate({username => $username, password => $password})
        || return;

    $user;
}

=head2 GET /login

Route the user will be sent to if login is required.

=cut

get '/login' => sub {

    # what are you doing? you're already in.
    return redirect uri_for('/librecat') if session('user');

    # not logged in yet
    template 'login',
        {
        error_message => params->{error_message} || '',
        login         => params->{login}         || '',
        return_url    => params->{return_url}    || '',
        lang          => h->locale()
        };
};

=head2 POST /login

Route where login data is sent to. On success redirects to
'/librecat' or to the path requested before

=cut

post '/login' => sub {
    my $user = _authenticate(params->{user}, params->{pass});
    my $return_url = params->{return_url} || uri_for("/librecat")->as_string();

    # Deleting bad urls to external websites
    $return_url = uri_for("/librecat")->as_string()
        unless index($return_url, request->uri_base()) == 0;

    if ($user) {
        h->login_user($user);
        redirect $return_url;
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

    h->logout_user();

    redirect uri_for('/');
};

=head2 GET /set_language

Route to call when changing language

=cut

get '/set_language' => sub {
    my $referer = request->referer // '/?';
    my $lang = param('lang');
    h->set_locale( $lang ) if h->locale_exists( $lang );
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

=head1 ANY {other route...}

Throws 'page not found'.

=cut

any qr{.*} => sub {
    status 'not_found';
    return template '404';
};

1;
