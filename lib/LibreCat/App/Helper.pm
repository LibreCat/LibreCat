package LibreCat::App::Helper::Helpers;

use FindBin;
use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Catmandu::Util qw(:io :is :array :hash :human trim);
use Catmandu::Fix qw(expand);
use Catmandu::Store::DBI;
use Dancer qw(:syntax params request session vars cookie);
use Dancer::FileUtils qw(path);
use File::Basename;
use POSIX qw(strftime);
use IO::Handle::Util;
use JSON::MaybeXS qw(encode_json);
use LibreCat qw(:self);
use LibreCat::I18N;
use LibreCat::JobQueue;
use Log::Log4perl ();
use NetAddr::IP::Lite;
use URI::Escape qw(uri_escape_utf8);
use Role::Tiny ();
use Moo;
use Clone qw(clone);

sub BUILD {
    my ($self) = @_;
    if (my $plugins = $self->config->{helper_plugins}) {
        Role::Tiny->apply_roles_to_object($self, @$plugins);
    }
}

sub log {
    my ($self) = @_;
    my ($package, $filename, $line) = caller;
    Log::Log4perl::get_logger($package);
}

sub config {
    state $config = hash_merge(Catmandu->config, Dancer::config);
}

sub hook {
    librecat->hook($_[1]);
}

sub queue {
    librecat->queue;
}

sub create_fixer {
    librecat->fixer($_[1]);
}

sub alphabet {
    return ['A' .. 'Z'];
}

sub main_audit {
    state $bag = Catmandu->store('main')->bag('audit');
}

sub main_publication {
    librecat->model('publication')->bag;
}

sub main_project {
    librecat->model('project')->bag;
}

sub main_user {
    librecat->model('user')->bag;
}

sub main_department {
    librecat->model('department')->bag;
}

sub main_research_group {
    librecat->model('research_group')->bag;
}

sub main_reqcopy {
    state $bag = Catmandu->store('main')->bag('reqcopy');
}

sub publication {
    librecat->model('publication')->search_bag;
}

sub project {
    librecat->model('project')->search_bag;
}

sub user {
    librecat->model('user')->search_bag;
}

sub department {
    librecat->model('department')->search_bag;
}

sub research_group {
    librecat->model('research_group')->search_bag;
}

sub within_ip_range {
    my ($self, $ip, $range) = @_;

    $range = []       unless defined $range;
    $range = [$range] unless is_array_ref($range);

    my $needle = NetAddr::IP::Lite->new($ip);

    for my $haystack (@$range) {
        return 1 if $needle->within(NetAddr::IP::Lite->new($haystack));
    }

    return undef;
}

sub string_array {
    my ($self, $val) = @_;
    return [grep {is_string $_ } @$val] if is_array_ref $val;
    return [$val] if is_string $val;
    [];
}

sub nested_params {
    my ($self, $params) = @_;

    state $fixer = Catmandu::Fix->new(fixes => ["expand()"]);

    $params ||= params;
    foreach my $k (keys %$params) {
        unless (defined $params->{$k}) {
            delete $params->{$k};
            next;
        }
        delete $params->{$k} if ($params->{$k} =~ /^$/);
    }

    $fixer->fix($params);
}

sub extract_params {
    my ($self, $params) = @_;

    $params ||= params;
    my $p = {};
    return $p if ref $params ne 'HASH';

    # parameters configured in helper.yml
    foreach my $key (keys %{$self->config->{helper}->{extract_params}}) {
        if ($self->config->{helper}->{extract_params}->{$key} eq "exists") {
            $p->{$key} = $params->{$key} if $params->{$key};
        }
        elsif (
            $self->config->{helper}->{extract_params}->{$key} eq "is_natural")
        {
            $p->{$key} = $params->{$key} if is_natural $params->{$key};
        }
        elsif ($self->config->{helper}->{extract_params}->{$key} eq
            "string_array")
        {
            $p->{$key} = $self->string_array($params->{$key})
                if $params->{$key};
        }
    }

    # additional parameters with more complex logic
    ($params->{text} =~ /^".*"$/)
        ? (push @{$p->{q}}, $params->{text})
        : (push @{$p->{q}}, join(" AND ", split(/ |-/, $params->{text})))
        if $params->{text};

    $p;
}

sub now {
    librecat->timestamp($_[1]);
}

sub pretty_byte_size {
    my ($self, $number) = @_;
    return $number ? human_byte_size($number) : '';
}

sub is_marked {
    my ($self, $id) = @_;
    my $marked = Dancer::session 'marked';
    return Catmandu::Util::array_includes($marked, $id);
}

sub all_marked {
    my ($self) = @_;
    my $p = $self->extract_params();
    push @{$p->{cql}}, $p->{q} if $p->{q};
    push @{$p->{cql}}, "status=public";

    my $hits       = librecat->searcher->search('publication', $p);
    my $marked     = Dancer::session 'marked';
    my $all_marked = 1;

    $hits->each(
        sub {
            unless (Catmandu::Util::array_includes($marked, $_[0]->{_id})) {
                $all_marked = 0;
            }
        }
    );

    return $all_marked;
}

sub get_publication {
    librecat->model('publication')->get($_[1]);
}

sub get_person {
    librecat->model('user')->find($_[1]);
}

sub get_project {
    librecat->model('project')->get($_[1]);
}

sub get_department {
    if ($_[1] && length $_[1]) {
        librecat->model('department')->get($_[1]);
    }
}

sub get_list {
    return $_[0]->config->{lists}->{$_[1]};
}

sub get_relation {
    my ($self, $list, $relation) = @_;

    my $map = $self->get_list($list);
    my %hash_list = map {$_->{relation} => $_} @$map;
    $hash_list{$relation};
}

sub get_statistics {
    my ($self) = @_;

    my $hits = librecat->searcher->search('publication',
        {cql => ["status=public"]});

    my $people = librecat->searcher->search('user',
        {cql => ["publication_count>0"]});

    my $oahits = librecat->searcher->search('publication',
        {cql => ["status=public", "oa=1"]});

    return {
        publications => $hits->{total},
        researcher   => $people->{total},
        oahits       => $oahits->{total},
        projects     => $self->project->count(),
    };
}

sub uri_base {

    #config option 'host' is deprecated
    state $h = $_[0]->config->{uri_base} // $_[0]->config->{host}
        // "http://localhost:5001";
}

sub uri_for {
    my ($self, $path, $params) = @_;

    if ( $self->show_locale ) {

        $params = clone($params);
        $params->{lang} = $self->locale();

    }

    my $uri = $self->uri_base();

    $uri .= $path if $path;

    my @request_param;

    if (is_hash_ref($params)) {
        for my $key (sort keys %$params) {
            my $value = $params->{$key};

            if (!defined($value) || length($value) == 0) {
                $value = [];
            }
            elsif (is_array_ref($value)) { }
            elsif (is_string($value)) {
                $value = [$value];
            }
            else {
                $self->log->error(
                    "expecting an array or string but got a $value");
                $value = [];
            }

            for (@$value) {
                push @request_param,
                    uri_escape_utf8($key) . "=" . uri_escape_utf8($_);
            }
        }
    }

    if (@request_param) {
        $uri .= '?' . join("&", @request_param);
    }

    return $uri;
}

sub get_file_store {
    my ($self) = @_;

    my $file_store = $self->config->{filestore}->{default}->{package};
    my $file_opts = $self->config->{filestore}->{default}->{options} // {};

    return undef unless $file_store;

    my $pkg = Catmandu::Util::require_package($file_store,
        'Catmandu::Store::File');
    $pkg->new(%$file_opts);
}

sub get_access_store {
    my ($self) = @_;

    my $access_store = $self->config->{filestore}->{access}->{package};
    my $access_opts = $self->config->{filestore}->{access}->{options} // {};

    return undef unless $access_store;

    my $pkg = Catmandu::Util::require_package($access_store,
        'Catmandu::Store::File');
    $pkg->new(%$access_opts);
}

sub get_temp_store {
    my ($self) = @_;

    my $temp_store = $self->config->{filestore}->{temp}->{package};
    my $temp_opts  = $self->config->{filestore}->{temp}->{options} // {};

    return undef unless $temp_store;

    my $pkg = Catmandu::Util::require_package($temp_store,
        'Catmandu::Store::File');
    $pkg->new(%$temp_opts);
}

sub show_locale {
    $_[0]->config->{i18n}->{show_locale};
}

sub locale {
    cookie('lang') // $_[0]->default_locale();
}

sub set_locale {
    cookie( 'lang', $_[1] );
}

sub available_locales {
    state $locales = [
        sort
        grep { index($_,"_") != 0 }
        keys %{ $_[0]->config->{i18n}->{lexicon} }
    ];
}
#everything that starts with an underscore is a lexicon option, not a language
sub locale_exists {
    is_string( $_[1] ) &&
        index( $_[1], "_" ) != 0 &&
        exists( $_[0]->config->{i18n}->{lexicon}->{ $_[1] } );
}

sub default_locale {
    state $dl = do {
        is_string( $_[0]->config->{default_lang} ) or die( "default_lang is not set in config" );
        $_[0]->config->{default_lang};
    };
}

sub locale_long {
    my ( $self, $locale ) = @_;
    is_string( $locale ) &&
        is_string( $self->config->{i18n}->{locale_long}->{$locale} ) ?
            $self->config->{i18n}->{locale_long}->{$locale} : $locale;
}

# Create an IO::Handle from a Plack writer
# Add a virtual 'syswrite' method to a Plack writer stream
sub io_from_plack_writer {
    my ($self, $writer) = @_;
    return IO::Handle::Util::io_prototype write => sub {
        my $self = shift;
        $writer->write(@_);
        },
        syswrite => sub {
        my $self = shift;
        $writer->write(@_);
        },
        close => sub {
        my $self = shift;
        $writer->close;
        }
}

sub localize {
    my ($self, $str) = @_;
    state $locales = {};
    my $loc = $self->locale;
    my $i18n = $locales->{$loc} //= LibreCat::I18N->new(locale => $loc);
    $i18n->localize($str);
}
sub uri_for_locale {
    my ( $self, $locale ) = @_;
    my $request = request();
    my $path_info = $request->path_info();
    my %params = (params("query"),params("body"));
    $params{lang} = $locale;
    $request->uri_for( $path_info, \%params );
}

*loc = \&localize;

sub file_extension {
    my ($self, $path) = @_;
    (fileparse($path, qr/\.[^\.]*/))[2];
}

sub uri_for_file {
    my ($self, $pub_id, $file_id, $file_name) = @_;
    my $ext = $self->file_extension($file_name);
    $self->uri_base() . "/download/$pub_id/$file_id$ext";
}

sub login_user {

    my ($self, $user) = @_;

    my %attrs = librecat->model('user')->to_session($user);

    for (keys %attrs) {

        session($_ => $attrs{$_});

    }

}

sub logout_user {

    session role     => undef;
    session user     => undef;
    session user_id  => undef;

}

package LibreCat::App::Helper;

=head1 NAME

LibreCat::App::Helper - a helper package with utility functions

=head1 SYNOPSIS

    # usage in perl code
    use LibreCat::App::Helper;
    # symbol h is automatically imported

    my $uri_base = h->uri_base; # get hostname

    # usage in templates
    <a href="[% h.uri_base %]/record">Publications</a>

=cut

my $h = LibreCat::App::Helper::Helpers->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook param request);
use Dancer::Plugin;

register h => sub {$h};

hook before_template => sub {
    $_[0]->{h}        = $h;
    $_[0]->{uri_base} = $h->uri_base();

};
hook before => sub {

    #set lang when sent
    {
        my $lang = param("lang");
        if ( request->is_get() && $h->locale_exists( $lang ) ) {

            $h->set_locale( $lang );

        }

    }

};

register_plugin;

1;
