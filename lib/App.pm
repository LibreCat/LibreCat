package App;

=head1 NAME

App - a webapp that runs an awesome institutional repository.

=cut

#BEGIN {
#use Catmandu::Sane;
#use Catmandu;
#use LibreCat::Layers;
#use Dancer qw(:syntax setting set);
#use Clone qw(clone);

#my $layers = LibreCat::Layers->new;
#my $config = clone(Catmandu->config->{dancer});
#my $env = setting('environment');
#my $env_config = (delete($config->{_environments}) || {})->{$env} || {};
#my %mergeable = (plugins => 1, handlers => 1);
#for my $key (keys %$env_config) {
#if ($mergeable{$key}) {
#$config->{$key}{$_} = $env_config->{$key}{$_} for keys %{$env_config->{$key}};
#} else {
#$config->{$key} = $env_config->{$key};
#}
#}
#$config->{engines}{template_toolkit}{INCLUDE_PATH} //= $layers->template_paths;
## TODO only if log level is debug
#$config->{engines}{template_toolkit}{DEBUG} //= 'provider' if $env eq 'development';
#set %$config;
#}

use Catmandu::Sane;

our $VERSION = '0.01';

use Catmandu::Util;
use LibreCat::User;

use Dancer qw(:syntax);

use App::Search;       # the frontend
use App::Catalogue;    # the backend
use App::Api;          # the api

use App::Helper;
use Dancer::Plugin::Auth::Tiny;
use Dancer::Plugin::DirectoryView;

# make variables with leading '_' visible in TT,
# otherwise they are considered private
$Template::Stash::PRIVATE = 0;

directory_view '/RePEc';

# custom authenticate routine
sub _authenticate {
    my ($username, $password) = @_;

    my $users = LibreCat::User->new(Catmandu->config->{user});

    my $auth = do {
        my $pkg = Catmandu::Util::require_package(
            h->config->{authentication}->{package});
        my $param = h->config->{authentication}->{options} // {};
        $pkg->new($param);
    };

    my $user = $users->find_by_username($username) || return;
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
        lang          => session->{lang}         || h->config->{default_lang}
        };
};

=head2 POST /login

Route where login data is sent to. On success redirects to
'/librecat' or to the path requested before

=cut

post '/login' => sub {

    my $user = _authenticate(params->{user}, params->{pass});

    if ($user) {
        my $super_admin  = "super_admin"  if $user->{super_admin};
        my $reviewer     = "reviewer"     if $user->{reviewer};
        my $data_manager = "data_manager" if $user->{data_manager};
        my $delegate     = "delegate"     if $user->{delegate};
        session role => $super_admin
            || $reviewer
            || $data_manager
            || $delegate
            || "user";
        session user         => $user->{login};
        session personNumber => $user->{_id};
        session lang         => $user->{lang} || h->config->{default_lang};

        redirect '/librecat';
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

    # preserves language setting only
    my $lang = session->{lang};
    session->destroy;
    session lang => $lang;

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
    template 'websites/403', {path => params->{referer}};
};

any qr{(/en)*/coffee} => sub {
    status '418';
    template 'websites/418', {path => request->{referer}};
};

=head1 ANY {other route....}

Throws 'page not found'.

=cut

any qr{.*} => sub {
    status 'not_found';
    template 'websites/404', {path => request->{referer}};
};

1;
