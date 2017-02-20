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
use Moo;

sub log {
    my ($self) = @_;
    my ($package, $filename, $line) = caller;
    Log::Log4perl::get_logger($package);
}

sub config {
    state $config = hash_merge(Catmandu->config, Dancer::config);
}

sub hook {
    LibreCat->hook($_[1]);
}

sub queue {
    state $config = LibreCat::JobQueue->new;
}

sub create_fixer {
    my ($self, $file) = @_;

    $self->log->debug("searching for fix `$file'");

    for my $p (@{LibreCat->layers->fixes_paths}) {
        $self->log->debug("testing `$p/$file'");
        if (-r "$p/$file") {
            $self->log->debug("found `$p/$file'");
            return Catmandu::Fix->new(fixes => ["$p/$file"]);
        }
    }

    $self->log->error("can't find a fixer for: `$file'");

    return Catmandu::Fix->new();
}

sub alphabet {
    return ['A' .. 'Z'];
}

sub bag {
    state $bag = Catmandu->store->bag;
}

sub backup_audit {
    state $bag = Catmandu->store('backup')->bag('audit');
}

sub backup_publication {
    state $bag = Catmandu->store('backup')->bag('publication');
}

sub backup_publication_static {
    my ($self) = @_;
    my $backup = Catmandu::Store::DBI->new(
        'data_source' =>
            $self->config->{store}->{backup}->{options}->{data_source},
        username => $self->config->{store}->{backup}->{options}->{username},
        password => $self->config->{store}->{backup}->{options}->{password},
        bags     => {publication => {plugins => ['Versioning']}},
    );
    state $bag = $backup->bag('publication');
}

sub backup_project {
    state $bag = Catmandu->store('backup')->bag('project');
}

sub backup_researcher {
    state $bag = Catmandu->store('backup')->bag('researcher');
}

sub backup_department {
    state $bag = Catmandu->store('backup')->bag('department');
}

sub backup_research_group {
    state $bag = Catmandu->store('backup')->bag('research_group');
}

sub publication {
    state $bag = Catmandu->store('search')->bag('publication');
}

sub project {
    state $bag = Catmandu->store('search')->bag('project');
}

sub researcher {
    state $bag = Catmandu->store('search')->bag('researcher');
}

sub department {
    state $bag = Catmandu->store('search')->bag('department');
}

sub research_group {
    state $bag = Catmandu->store('search')->bag('research_group');
}

sub within_ip_range {
    my ($self, $ip, $range) = @_;

    $range = [] unless defined $range;
    $range = [ $range ] unless is_array_ref($range);

    my $needle = NetAddr::IP::Lite->new($ip);

    for my $haystack (@$range) {
        return 1 if $needle->within( NetAddr::IP::Lite->new($haystack) );
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
    $p->{q}     = $params->{q} if $params->{q};
    $p->{cql}   = $self->string_array($params->{cql});

    ($params->{text} =~ /^".*"$/)
        ? (push @{$p->{q}}, $params->{text})
        : (push @{$p->{q}}, join(" AND ", split(/ |-/, $params->{text})))
        if $params->{text};

    $p->{style} = $params->{style} if $params->{style};
    $p->{sort} = $self->string_array($params->{'sort'}) if $params->{'sort'};

    $p;
}

sub get_sort_style {
    my ($self, $param_sort, $param_style, $id) = @_;

    my $user = {};
    $user = $self->get_person($id || Dancer::session->{personNumber});
    my $return;
    $param_sort = undef
        if ($param_sort eq ""
        or (ref $param_sort eq "ARRAY" and !$param_sort->[0]));
    $param_style = undef if $param_style eq "";
    my $user_style = "";
    $user_style = $user->{style} if ($user && $user->{style});

    # set default values - to be overridden by more important values
    my $style;
    if (
        $param_style
        && array_includes(
            $self->config->{citation}->{csl}->{styles}, $param_style
        )
        )
    {
        $style = $param_style;
    }
    elsif (
        $user_style
        && array_includes(
            $self->config->{citation}->{csl}->{styles}, $user_style
        )
        )
    {
        $style = $user_style;
    }
    else {
        $style = $self->config->{citation}->{csl}->{default_style};
    }

    my $sort;
    my $sort_backend;
    if ($param_sort) {
        $param_sort = [$param_sort] if ref $param_sort ne "ARRAY";
        $sort = $sort_backend = $param_sort;
    }
    else {
        $sort         = $self->config->{default_sort};
        $sort_backend = $self->config->{default_sort_backend};
    }

    $return->{sort}                 = $sort;
    $return->{sort_backend}         = $sort_backend;
    $return->{user_style}           = $user_style if ($user_style);
    $return->{default_sort}         = $self->config->{default_sort};
    $return->{default_sort_backend} = $self->config->{default_sort_backend};

    $return->{style} = $style // "";

    Catmandu::Fix->new(fixes => ["vacuum()"])->fix($return);

    $return->{sort_eq_default} = 0;
    $return->{sort_eq_default} = is_same($return->{sort_backend},
        $self->config->{default_sort_backend});

    $return->{style_eq_userstyle} = 0;
    $return->{style_eq_userstyle} = ($user_style eq $return->{style}) ? 1 : 0;
    $return->{style_eq_default}   = 0;
    $return->{style_eq_default}
        = (
        $return->{style} eq $self->config->{citation}->{csl}->{default_style})
        ? 1
        : 0;

    return $return;
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
    my $sort_style
        = $self->get_sort_style($p->{sort} || '', $p->{style} || '');
    $p->{sort} = $sort_style->{'sort'};
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
        my $hits = LibreCat->searcher->search('researcher', {cql => ["id=$id"]});
        $hits = LibreCat->searcher->search('researcher', {cql => ["login=$id"]})
            if !$hits->{total};
        return $hits->{hits}->[0] if $hits->{total};
        if (my $user = LibreCat->user->get($id) || LibreCat->user->find_by_username($id)) {
            return $user;
        }
    }
}

sub get_project {
    $_[0]->project->get($_[1]);
}

sub get_department {
    if ($_[1] && length $_[1]) {
        my $result = $_[0]->department->get($_[1]);
        $result = LibreCat->searcher->search('department', {q => ["name=\"$_[1]\""]})->first
            if !$result;
        return $result;
    }
}

sub get_research_group {
    $_[0]->research_group->get($_[1]);
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
        {
            cql => [
                "status=public",      "fulltext=1",
                "type<>research_data",
            ]
        }
    );

    return {
        publications => $hits->{total},
        researchdata => $reshits->{total},
        oahits       => $oahits->{total},
        projects => $self->project->count(),
    };

}

sub get_metrics {
    my ($self, $bag, $id) = @_;
    return {} unless $bag and $id;

    return Catmandu->store('metrics')->bag($bag)->get($id);
}

sub new_record {
    my ($self, $bag) = @_;
    Catmandu->store('backup')->bag($bag)->generate_id;
}

sub update_record {
    my ($self, $bag, $rec) = @_;

    $self->log->info("updating $bag");

    if ($self->log->is_debug) {
        $self->log->debug(Dancer::to_json($rec));
    }

    $rec = $self->store_record($bag, $rec);
    $self->index_record($bag, $rec);

    sleep 1;    # bad hack!

    $rec;
}

sub store_record {
    my ($self, $bag, $rec, $skip_citation) = @_;

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
            my $super_id = $self->config->{store}->{builtin_users}->{options}->{init_data}->[0]->{_id};
            $rec->{user_id} = $super_id;
        }
    }

    # memoize fixes
    state $fixes = {};
    my $fix = $fixes->{$bag} //= $self->create_fixer("update_$bag.fix");
    $fix->fix($rec);

    state $cite_fix = Catmandu::Fix->new(fixes => ["add_citation()"]);
    if ($bag eq 'publication' && !$skip_citation) {
        $cite_fix->fix($rec);
    }

    # clean all the fields that are not part of the JSON schema
    state $validators = {};
    my $validator_pkg = $validators->{$bag} //= Catmandu::Util::require_package(ucfirst($bag),
                                                        'LibreCat::Validator');
    if ($validator_pkg) {
        my @white_list = $validator_pkg->new->white_list;

        $self->log->fatal("no white_list found for $validator_pkg ??!") unless @white_list;

        for my $key (keys %$rec) {
            unless (grep(/^$key$/, @white_list)) {
                $self->log->debug("deleting invalid key: $key");
                delete $rec->{$key}
            }
        }
    }

    my $bagname = "backup_$bag";
    $self->log->debug("storing record in $bagname...");
    $self->log->debug(Dancer::to_json($rec));
    $self->$bagname->add($rec);
}

sub index_record {
    my ($self, $bag, $rec) = @_;

    #compare version! through _version or through date_updated
    $self->log->debug("indexing record in $bag...");
    $self->log->debug(Dancer::to_json($rec));
    $self->$bag->add($rec);
    $self->$bag->commit;
    $rec;
}

sub delete_record {
    my ($self, $bag, $id) = @_;

    my $del_record = $self->$bag->get($id);

    if ($bag eq 'publication' &&
            ($del_record->{oai_deleted} || $del_record->{status} eq 'public')
            ) {
        $del_record ->{oai_deleted}  = 1
    }

    $del_record->{date_deleted} = $self->now;
    $del_record->{status}       = 'deleted';

    my $bagname = "backup_$bag";
    my $saved   = $self->$bagname->add($del_record);
    $self->$bag->add($saved);
    $self->$bag->commit;

    sleep 1;

    return $saved;
}

sub purge_record {
    my ($self, $bag, $id) = @_;

    if ($bag eq 'publication') {
        my $rec = $self->publication->delete($id);
    }

    my $bagname = "backup_$bag";
    $self->$bagname->delete($id);
    $self->$bag->commit;

    return 1;
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

sub host {
    $_[0]->config->{host};
}

sub export_publication {
    my ($self, $hits, $fmt, $to_string) = @_;

    if (my $spec = config->{exporter}->{publication}->{$fmt}) {
        my $package = $spec->{package};
        my $options = $spec->{options} || {};

        $options->{style} = $hits->{style} || 'default';
        $options->{explinks} = params->{explinks};
        my $content_type = $spec->{content_type} || mime->for_name($fmt);
        my $extension    = $spec->{extension}    || $fmt;

        my $f = export_to_string($hits, $package, $options);
        return $f if $to_string;

        return Dancer::send_file(
            \$f,
            content_type => $content_type,
            filename     => "publications.$extension"
        );
    }
}

sub get_department_tree {
    my ($self) = @_;
    LibreCat->searcher->search('department', { sort => 'name.desc'} )->to_array;
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
    my $access_opts  = $self->config->{filestore}->{access}->{options} // {};

    return undef unless $access_store;

    my $pkg
        = Catmandu::Util::require_package($access_store, 'LibreCat::FileStore');
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
    request->uri_base . "/download/$pub_id/$file_id$ext";
}

package LibreCat::App::Helper;

my $h = LibreCat::App::Helper::Helpers->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook);
use Dancer::Plugin;

register h => sub {$h};

hook before_template => sub {

    $_[0]->{h} = $h;

};

register_plugin;

1;
