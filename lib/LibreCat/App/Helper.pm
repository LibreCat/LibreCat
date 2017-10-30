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

sub hook {
    LibreCat->hook($_[1]);
}

sub queue {
    state $config = LibreCat::JobQueue->new;
}

sub layers {
    LibreCat->layers;
}

sub create_fixer {
    my ($self, $file) = @_;

    $self->log->debug("searching for fix `$file'");

    for my $p (@{$self->layers->fixes_paths}) {
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

sub main_audit {
    state $bag = Catmandu->store('main')->bag('audit');
}

sub main_publication {
    state $bag = Catmandu->store('main')->bag('publication');
}

sub main_project {
    state $bag = Catmandu->store('main')->bag('project');
}

sub main_user {
    state $bag = Catmandu->store('main')->bag('user');
}

sub main_department {
    state $bag = Catmandu->store('main')->bag('department');
}

sub main_research_group {
    state $bag = Catmandu->store('main')->bag('research_group');
}

sub main_reqcopy {
    state $bag = Catmandu->store('main')->bag('reqcopy');
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
    $p->{lang}  = $self->locale_exists( $params->{lang} ) ? $params->{lang} : $self->locale();
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

sub new_record {
    my ($self, $bag) = @_;
    Catmandu->store('main')->bag($bag)->generate_id;
}

sub update_record {
    my ($self, $bag, $rec) = @_;

    $self->log->info("updating $bag");

    if ($self->log->is_debug) {
        $self->log->debug(Dancer::to_json($rec));
    }

    $rec = $self->store_record(
        $bag, $rec,
        validation_error => sub {
            my $validator = shift;

            # At least cry foul when the record doesn't validate
            $self->log->error($rec->{_id} . " not a valid publication!");
            $self->log->error(Dancer::to_json($validator->last_errors));
        }
    );

    $self->index_record($bag, $rec);

    sleep 1;    # bad hack!

    $rec;
}

sub store_record {
    my ($self, $bag, $rec, %opts) = @_;

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

    # clean all the fields that are not part of the JSON schema
    state $validators = {};
    my $validator_pkg = $validators->{$bag};
    $validator_pkg //= Catmandu::Util::require_package(ucfirst($bag),'LibreCat::Validator');

    my $can_store = 1;

    if ($validator_pkg) {
        my $validator = $validator_pkg->new;

        my @white_list = $validator->white_list;

        $self->log->fatal("no white_list found for $validator_pkg ??!")
            unless @white_list;

        for my $key (keys %$rec) {
            unless (grep(/^$key$/, @white_list)) {
                $self->log->debug("deleting invalid key: $key");
                delete $rec->{$key};
            }
        }

        unless ($validator->is_valid($rec)) {
            $can_store = 0;
            $opts{validation_error}->($validator, $rec)
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
    #compare version! through _version or through date_updated
    $self->log->debug("indexing record in $bag...");
    $self->log->debug(Dancer::to_json($rec));
    $self->$bag->add($rec);
    $self->$bag->commit;
    $rec;
}

sub delete_record {
    my ($self, $bag, $id) = @_;

    if ($bag eq 'publication') {
        my $del_record = $self->publication->get($id);

        if ($del_record->{oai_deleted} || $del_record->{status} eq 'public') {
            $del_record->{oai_deleted} = 1;
            $del_record->{locked}      = 1;
        }

        $del_record->{date_deleted} = $self->now;
        $del_record->{status}       = 'deleted';


        my $saved   = $self->main_publication->add($del_record);
        $self->main_publication->commit;
        $self->publication->add($saved);
        $self->publication->commit;

        sleep 1;

        return $saved;
    }
    else {
        $self->purge_record($bag,$id);
        return +{};
    }
}

sub purge_record {
    my ($self, $bag, $id) = @_;

    # Delete from the index store
    $self->$bag->delete($id);
    $self->$bag->commit;

    # Delete from the main store
    my $bagname = "main_$bag";
    $self->$bagname->delete($id);
    $self->$bagname->commit;

    return 1;
}

sub display_doctypes {
    my ( $self, $type, $lang ) = @_;
    $type = lc( $type );
    $lang = $self->locale_exists( $lang ) ? $lang :  $self->default_locale();
    $self->config->{language}->{$lang}->{forms}->{$type}->{label};
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
        = Catmandu::Util::require_package($file_store, 'Catmandu::Store::File');
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

sub localize {
    my ($self, $str) = @_;
    state $locales = {};
    my $loc = $self->locale;
    my $i18n = $locales->{$loc} //= LibreCat::I18N->new(locale => $loc);
    $i18n->localize($str);
}
sub uri_for_locale {
    my ( $self, $locale ) = @_;
    my @path;
    if ( defined( Dancer::session("user") ) ) {
        push @path, "/librecat/person";
    }
    push @path, "/set_language";
    $self->uri_for( join('',@path), { lang => $locale } );
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
