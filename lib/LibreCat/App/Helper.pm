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
use LibreCat qw(:self);
use LibreCat::I18N;
use LibreCat::JobQueue;
use Log::Log4perl ();
use NetAddr::IP::Lite;
use URI::Escape qw(uri_escape_utf8);
use Role::Tiny ();
use Moo;

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
    push @{$p->{q}}, "status=public";

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

sub new_record {
    my ($self, $bag) = @_;
    $self->log->warn(
        'DEPRECATION NOTICE: new_record is deprecated. Use librecat->model($model)->generate_id instead'
    );
    Catmandu->store('main')->bag($bag)->generate_id;
}

sub update_record {
    my ($self, $bag, $rec) = @_;
    $self->log->warn(
        'DEPRECATION NOTICE: update_record is deprecated. Use librecat->model($model)->add instead'
    );

    my $saved_record = $self->store_record($bag,$rec);

    $self->index_record($bag, $saved_record);

    sleep 1;    # bad hack!

    $rec;
}

sub store_record {
    my ($self, $bag, $rec, %opts) = @_;
    $self->log->warn(
        'DEPRECATION NOTICE: store_record is deprecated. Use librecat->model($model)->add instead'
    );

    # don't know where to put it, should find better place to handle this
    # especially the async stuff
    if ($bag eq 'publication') {
        require LibreCat::App::Catalogue::Controller::File;
        require LibreCat::App::Catalogue::Controller::Material;

        LibreCat::App::Catalogue::Controller::File::handle_file($rec);

        if ($rec->{related_material}) {
            LibreCat::App::Catalogue::Controller::Material::update_related_material(
                $rec);
        }

        # Set for every update the user-id of the last editor
        unless ($rec->{user_id}) {

            # Edit by a user via the command line?
            my $super_id = $self->config->{store}->{builtin_users}->{options}
                ->{init_data}->[0]->{_id} // 'undef';
            $rec->{user_id} = $super_id;
        }
    }

    # memoize fixes
    state $fixes = {};
    my $fix = $fixes->{$bag} //= $self->create_fixer("update_$bag.fix");
    $fix->fix($rec);

    state $cite_fix = Catmandu::Fix->new(fixes => ["add_citation()"]);
    if ($bag eq 'publication') {
        $cite_fix->fix($rec) unless $opts{skip_citation};
    }

    my $can_store = 1;

    if (librecat->has_model($bag)) {
        my $model = librecat->model($bag);

        unless ($model->is_valid($rec)) {
            $can_store = 0;
            $opts{validation_error}->($model->validator, $rec)
                if $opts{validation_error}
                && ref($opts{validation_error}) eq 'CODE';
        }
    }

    if ($can_store) {
        my $bagname = "main_$bag";
        $self->log->debug("storing record in $bagname...");
        $self->log->debug(Dancer::to_json($rec));
        my $saved_record = $self->$bagname->add($rec);
        $self->$bagname->commit;
        return $saved_record;
    }
    else {
        return undef;
    }
}

sub index_record {
    my ($self, $bag, $rec) = @_;
    $self->log->warn(
        'DEPRECATION NOTICE: index_record is deprecated. Use librecat->model($model)->add instead'
    );

    #compare version! through _version or through date_updated
    $self->log->debug("indexing record in $bag...");

    # memoize fixes
    state $fixes = {};
    my $fix = $fixes->{$bag} //= $self->create_fixer("index_$bag.fix");
    $fix->fix($rec);

    $self->log->debug(Dancer::to_json($rec));
    $self->$bag->add($rec);
    $self->$bag->commit;
    $rec;
}

sub delete_record {
    my ($self, $bag, $id) = @_;
    $self->log->warn(
        'DEPRECATION NOTICE: delete_record is deprecated. Use librecat->model($model)->delete instead'
    );

    if ($bag eq 'publication') {
        my $del_record = $self->publication->get($id);

        return undef unless $del_record;

        if ($del_record->{oai_deleted} || $del_record->{status} eq 'public') {
            $del_record->{oai_deleted} = 1;
            $del_record->{locked}      = 1;
        }

        $del_record->{date_deleted} = $self->now;
        $del_record->{status}       = 'deleted';

        my $saved = $self->main_publication->add($del_record);
        $self->main_publication->commit;
        $self->publication->add($saved);
        $self->publication->commit;

        sleep 1;

        return $saved;
    }
    else {
        $self->purge_record($bag, $id);
        return +{};
    }
}

sub purge_record {
    my ($self, $bag, $id) = @_;
    $self->log->warn(
        'DEPRECATION NOTICE: delete_record is deprecated. Use librecat->model($model)->purge instead'
    );

    # Delete from the index store
    $self->$bag->delete($id);
    $self->$bag->commit;

    # Delete from the main store
    my $bagname = "main_$bag";
    $self->$bagname->delete($id);
    $self->$bagname->commit;

    return 1;
}

sub uri_base {

    #config option 'host' is deprecated
    state $h = $_[0]->config->{uri_base} // $_[0]->config->{host}
        // "http://localhost:5001";
}

sub uri_for {
    my ($self, $path, $params) = @_;

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
    session auth_sso => undef;

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
    <a href="[% h.uri_base %]/publication">Publications</a>

=cut

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
