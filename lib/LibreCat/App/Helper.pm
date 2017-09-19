package LibreCat::App::Helper::Helpers;

use FindBin;
use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Catmandu::Util qw(:io :is :array :hash :human trim);
use Catmandu::Fix qw(expand);
use Catmandu::Store::DBI;
use Dancer qw(:syntax params request session vars);
use Dancer::FileUtils qw(path);
use File::Basename;
use POSIX qw(strftime);
use JSON::MaybeXS qw(encode_json);
use LibreCat;
use LibreCat::I18N;
use LibreCat::JobQueue;
use Log::Log4perl ();
use NetAddr::IP::Lite;
use URI::Escape qw(uri_escape_utf8);
use Moo;

sub log {
    my ($self) = @_;
    my ($package, $filename, $line) = caller;
    Log::Log4perl::get_logger($package);
}

sub config {
    state $config = hash_merge(Catmandu->config, Dancer::config);
}

sub queue {
    state $config = LibreCat::JobQueue->new;
}

sub layers {
    LibreCat->layers;
}

sub alphabet {
    return ['A' .. 'Z'];
}

sub publication {
    state $bag = Catmandu->store('search')->bag('publication');
}

sub project {
    state $bag = Catmandu->store('search')->bag('project');
}

sub user {
    state $bag = Catmandu->store('search')->bag('user');
}

sub department {
    state $bag = Catmandu->store('search')->bag('department');
}

sub research_group {
    state $bag = Catmandu->store('search')->bag('research_group');
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

    $p->{start} = $params->{start} if is_natural $params->{start};
    $p->{limit} = $params->{limit} if is_natural $params->{limit};
    $p->{lang}  = $params->{lang}  if $params->{lang};
    $p->{q}     = $params->{q}     if $params->{q};
    $p->{cql} = $self->string_array($params->{cql});

    ($params->{text} =~ /^".*"$/)
        ? (push @{$p->{q}}, $params->{text})
        : (push @{$p->{q}}, join(" AND ", split(/ |-/, $params->{text})))
        if $params->{text};

    $p->{style} = $params->{style} if $params->{style};
    $p->{sort} = $self->string_array($params->{'sort'}) if $params->{'sort'};

    $p;
}

sub now {
    my $time = $_[1] // time;
    my $now = strftime($_[0]->config->{time_format}, gmtime($time));
    return $now;
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
    push @{$p->{q}}, "status=public";

    my $hits       = LibreCat->searcher->search('publication', $p);
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
    $_[0]->publication->get($_[1]);
}

# TODO clean this up
sub get_person {
    my ($self, $id) = @_;
    if ($id) {
        my $hits = LibreCat->searcher->search('user', {cql => ["id=$id"]});
        $hits = LibreCat->searcher->search('user', {cql => ["login=$id"]})
            if !$hits->{total};
        return $hits->{hits}->[0] if $hits->{total};
        if (my $user
            = LibreCat->user->get($id)
            || LibreCat->user->find_by_username($id))
        {
            return $user;
        }
    }
}

sub get_project {
    $_[0]->project->get($_[1]);
}

sub get_department {
    if ($_[1] && length $_[1]) {
        $_[0]->department->get($_[1]);
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

    my $hits = LibreCat->searcher->search('publication',
        {cql => ["status=public", "type<>research_data"]});
    my $reshits = LibreCat->searcher->search('publication',
        {cql => ["status=public", "type=research_data"]});
    my $oahits = LibreCat->searcher->search('publication',
        {cql => ["status=public", "fulltext=1", "type<>research_data",]});

    return {
        publications => $hits->{total},
        researchdata => $reshits->{total},
        oahits       => $oahits->{total},
        projects     => $self->project->count(),
    };

}

sub get_metrics {
    my ($self, $bag, $id) = @_;
    return {} unless $bag and $id;

    return Catmandu->store('metrics')->bag($bag)->get($id);
}

sub display_doctypes {
    my $type = lc $_[1];
    my $lang = $_[2] || "en";
    $_[0]->config->{language}->{$lang}->{forms}->{$type}->{label};
}

sub display_name_from_value {
    my ($self, $list, $value) = @_;

    my $map = $self->config->{lists}{$list};
    my $name;
    foreach my $m (@$map) {
        if ($m->{value} eq $value) {
            $name = $m->{name};
        }
    }
    $name;
}

sub uri_base {

    #config option 'host' is deprecated
    state $h = $_[0]->config->{uri_base} // $_[0]->config->{host}
        // "http://localhost:5001";
}

sub uri_for {
    my ($self, $path, $params) = @_;

    my @uri;

    push @uri, $self->uri_base(), $path;

    if (is_hash_ref($params)) {

        my @keys = keys %$params;

        push @uri, "?" if scalar(@keys);

        for my $key (@keys) {

            my $value = $params->{$key};
            $value
                = is_array_ref($value) ? $value
                : is_string($value)    ? [$value]
                :                        [];

            push @uri, join(
                "&",
                map {

                    uri_escape_utf8($key) . "=" . uri_escape_utf8($_);

                } @$value
            );

        }

    }

    join('', @uri);
}

sub get_file_store {
    my ($self) = @_;

    my $file_store = $self->config->{filestore}->{default}->{package};
    my $file_opts = $self->config->{filestore}->{default}->{options} // {};

    return undef unless $file_store;

    my $pkg
        = Catmandu::Util::require_package($file_store, 'LibreCat::FileStore');
    $pkg->new(%$file_opts);
}

sub get_access_store {
    my ($self) = @_;

    my $access_store = $self->config->{filestore}->{access}->{package};
    my $access_opts = $self->config->{filestore}->{access}->{options} // {};

    return undef unless $access_store;

    my $pkg = Catmandu::Util::require_package($access_store,
        'LibreCat::FileStore');
    $pkg->new(%$access_opts);
}

# TODO don't store in session, make it a param
sub locale {
    session('lang') // $_[0]->config->{default_lang};
}

sub localize {
    my ($self, $str) = @_;
    state $locales = {};
    my $loc = $self->locale;
    my $i18n = $locales->{$loc} //= LibreCat::I18N->new(locale => $loc);
    $i18n->localize($str);
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

package LibreCat::App::Helper;

my $h = LibreCat::App::Helper::Helpers->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook);
use Dancer::Plugin;

register h => sub {$h};

hook before_template => sub {

    $_[0]->{h}        = $h;
    $_[0]->{uri_base} = $h->uri_base();

};

register_plugin;

1;
