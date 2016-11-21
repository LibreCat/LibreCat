package LibreCat::App::Helper::Helpers;

use FindBin;
use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Catmandu::Util qw(:io :is :array :hash :human trim);
use Catmandu::Fix qw(expand);
use Catmandu::Store::DBI;
use Dancer qw(:syntax params request session vars);
use Dancer::FileUtils qw(path);
use POSIX qw(strftime);
use JSON::MaybeXS qw(encode_json);
use LibreCat;
use LibreCat::I18N;
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
    $p->{embed} = $params->{embed} if is_natural $params->{embed};
    $p->{lang}  = $params->{lang}  if $params->{lang};
    $p->{ttyp}  = $params->{ttyp}  if $params->{ttyp};
    $p->{ftyp}  = $params->{ftyp}  if $params->{ftyp};
    $p->{enum}  = $params->{enum}  if $params->{enum};

    if ($p->{ftyp} and $p->{ftyp} =~ /ajx|js|pln/ and !$p->{limit}) {
        $p->{limit} = $self->config->{maximum_page_size};
    }

    $p->{q} = array_uniq($self->string_array($params->{q}));

    my $cql = $params->{cql_query} ||= '';

    if ($cql) {
        my $deletedq;

        if (
            @$deletedq = (
                $cql
                    =~ /((?=AND |OR |NOT )?[0-9a-zA-Zäöüß]+\=\s|(?=AND |OR |NOT )?[0-9a-zA-Zäöüß]+\=$)/g
            )
            )
        {
            $cql
                =~ s/((AND |OR |NOT )?[0-9a-zA-Zäöüß]+\=\s|(AND |OR |NOT )?[0-9a-zA-Zäöüß]+\=$)/ /g;
        }
        $cql =~ s/^\s*(AND|OR)//g;
        $cql =~ s/,//g;
        $cql =~ s/\://g;
        $cql =~ s/\.//g;
        $cql =~ s/(NOT )(.*?)=/$2<>/g;
        $cql =~ s/(NOT )([^=]*?)/basic<>$2/g;
        $cql =~ s/(?<!")\b([^\s]+)\b, \b([^\s]+)\b(?!")/"$1, $2"/g;
        $cql =~ s/^\s+//;
        $cql =~ s/\s+$//;
        $cql =~ s/\s{2,}/ /;

        if ($cql
            !~ /^("[^"]*"|'[^']*'|[0-9a-zA-Zäöüß]+(=| ANY | ALL | EXACT )"[^"]*")$/
            and $cql
            !~ /^(([0-9a-zA-Zäöüß]+\=(?:[0-9a-zA-Zäöüß\-\*]+|"[^"]*"|'[^']*')+\**(?<!AND)(?<!OR)(?<!ANY)(?<!ALL)(?<!EXACT)|"[^"]*"|'[^']*') (AND|OR) ([0-9a-zA-Zäöüß]+\=(?:[0-9a-zA-Zäöüß\-\*]+|"[^"]*"|'[^']*')+\**(?<!AND)(?<!OR)|"[^"]*"|'[^']*'))$/
            and $cql
            !~ /^(([0-9a-zA-Zäöüß]+( ANY | ALL | EXACT )"[^"]*"|"[^"]*"|'[^']*'|[0-9a-zA-Zäöüß]+\=(?:[0-9a-zA-Zäöüß\-\*]+|"[^"]*"|'[^']*')+\**(?<!AND)(?<!OR))( (AND|OR) (([0-9a-zA-Zäöüß]+( ANY | ALL | EXACT )"[^"]*")|"[^"]*"|'[^']*'|[0-9a-zA-Zäöüß]+\=(?:[0-9a-zA-Zäöüß\-\*]+|"[^"]*"|'[^']*')+\**))*)$/
            )
        {
            $cql
                =~ s/((?:(?:(?:[0-9a-zA-Zäöüß\=\-\*]+(?<!AND)(?<!OR)|"[^"]*"|'[^']*') (?:AND|OR) )+(?:[0-9a-zA-Zäöüß\=\-\*]+(?<!AND)(?<!OR)|"[^"]*"|'[^']*'))|[0-9a-zA-Zäöüß\=\-\*]+(?<!AND)(?<!OR)|"[^"]*"|'[^']*')\s(?!AND )(?!OR )("[^"]*"|'[^']*'|.*?)/$1 AND $2/g;
        }
        push @{$p->{q}}, lc $cql;
    }

    ($params->{text} =~ /^".*"$/)
        ? (push @{$p->{q}}, $params->{text})
        : (push @{$p->{q}}, join(" AND ", split(/ |-/, $params->{text})))
        if $params->{text};

    # autocomplete functionality
    if ($params->{term}) {
        my $search_terms = join("* AND ", split(" ", $params->{term})) . "*"
            if $params->{term} !~ /^\d{1,}$/;
        my $search_id = $params->{term} if $params->{term} =~ /^\d{1,}$/;
        push @{$p->{q}},
              "title=("
            . lc $search_terms
            . ") OR person=("
            . lc $search_terms . ")"
            if $search_terms;
        push @{$p->{q}}, "id=$search_id OR person=$search_id" if $search_id;
        $p->{fmt} = $params->{fmt};
    }
    else {
        my $formats = $self->config->{exporter}->{publication};
        $p->{fmt}
            = ($params->{fmt} && $formats->{$params->{fmt}})
            ? $params->{fmt}
            : 'html';
    }

    $p->{style} = $params->{style} if $params->{style};
    $p->{sort} = $self->string_array($params->{'sort'}) if $params->{'sort'};

    $p;
}

sub hash_to_url {
    my ($self, $params) = @_;

    my $p = "";
    return $p if ref $params ne 'HASH';

    foreach my $key (keys %$params) {
        if (ref $params->{$key} eq "ARRAY") {
            foreach my $item (@{$params->{$key}}) {
                $p .= "&$key=$item";
            }
        }
        else {
            $p .= "&$key=$params->{$key}";
        }
    }
    return $p;
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

sub generate_urn {
    my ($self, $prefix, $id) = @_;
    my $nbn        = $prefix . $id;
    my $weighting  = ' 012345678 URNBDE:AC FGHIJLMOP QSTVWXYZ- 9K_ / . +#';
    my $faktor     = 1;
    my $productSum = 0;
    my $lastcifer;
    foreach my $char (split //, uc($nbn)) {
        my $weight = index($weighting, $char);
        if ($weight > 9) {
            $productSum += int($weight / 10) * $faktor++;
            $productSum += $weight % 10 * $faktor++;
        }
        else {
            $productSum += $weight * $faktor++;
        }
        $lastcifer = $weight % 10;
    }
    return $nbn . (int($productSum / $lastcifer) % 10);
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
        my $hits = LibreCat->searcher->search('researcher', {q => ["id=$id"]});
        $hits = LibreCat->searcher->search('researcher', {q => ["login=$id"]})
            if !$hits->{total};
        return $hits->{hits}->[0] if $hits->{total};
        if (my $user = LibreCat->user->get($id) || LibreCat->user->find_by_username($id)) {
            return $user;
        }
    }
    return {error => "something went wrong"};
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
        {q => ["status=public", "type<>research_data"]});
    my $reshits = LibreCat->searcher->search('publication',
        {q => ["status=public", "type=research_data"]});
    my $oahits = LibreCat->searcher->search('publication',
        {
            q => [
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
    my ($self, $bag, $rec) = @_;

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

    # clean all the fields that are not part of the JSON schema
    state $validator_pkg = Catmandu::Util::require_package(ucfirst($bag),
        'LibreCat::Validator');

    if ($validator_pkg) {
        my @white_list = $validator_pkg->new->white_list;
        for my $key (keys %$rec) {
            delete $rec->{$key} unless grep(/^$key$/, @white_list);
        }
    }

    my $bagname = "backup_$bag";

    $self->$bagname->add($rec);
}

sub index_record {
    my ($self, $bag, $rec) = @_;

    #compare version! through _version or through date_updated
    $self->$bag->add($rec);
    $self->$bag->commit;
    $rec;
}

sub delete_record {
    my ($self, $bag, $id) = @_;

    my $del = {_id => $id, date_deleted => $self->now, status => 'deleted',};

    if ($bag eq 'publication') {
        my $rec = $self->publication->get($id);
        $del->{date_created} = $rec->{date_created};
        $del->{oai_deleted}  = 1
            if ($rec->{oai_deleted} or $rec->{status} eq 'public');
        require LibreCat::App::Catalogue::Controller::File;
        require LibreCat::App::Catalogue::Controller::Material;
        LibreCat::App::Catalogue::Controller::Material::update_related_material(
            $del);
        LibreCat::App::Catalogue::Controller::File::handle_file($del);
        delete $del->{related_material};
    }

    my $bagname = "backup_$bag";
    my $saved   = $self->$bagname->add($del);
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

    if ($fmt eq 'autocomplete') {
        return $self->export_autocomplete_json($hits);
    }

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

sub export_autocomplete_json {
    my ($self, $hits) = @_;

    my $jsonhash = [];
    $hits->each(
        sub {
            my $hit = $_[0];
            if ($hit->{title} && $hit->{year}) {
                my $label = "$hit->{title} ($hit->{year}";
                my $author = $hit->{author} || $hit->{editor} || [];
                if (   $author
                    && $author->[0]->{first_name}
                    && $author->[0]->{last_name})
                {
                    $label
                        .= ", "
                        . $author->[0]->{first_name} . " "
                        . $author->[0]->{last_name} . ")";
                }
                else {
                    $label .= ")";
                }
                push @$jsonhash,
                    {
                    id    => $hit->{_id},
                    label => $label,
                    title => "$hit->{title}"
                    };
            }
        }
    );

    return Dancer::to_json($jsonhash);
}

sub get_department_tree {
    my ($self) = @_;
        my $tree;
        LibreCat->searcher->search('department', {})
        ->each(
            sub {
                my $hit = $_[0];
                push @$tree, $hit if $hit->{layer} == 1;
                #$tree->{$hit->{name}}->{display} = $hit->{display}
                #    if $hit->{layer} eq "1";
                # if ($hit->{layer} eq "2") {
                #     my $layer
                #         = $self->get_department($hit->{tree}->[0]->{_id});
                #     $tree->{$layer->{name}}->{$hit->{name}}->{id}
                #         = $hit->{tree}->[1]->{_id};
                #     $tree->{$layer->{name}}->{$hit->{name}}->{display}
                #         = $hit->{display};
                # }
                # if ($hit->{layer} eq "3") {
                #     my $layer2
                #         = $self->get_department($hit->{tree}->[0]->{_id});
                #     my $layer3
                #         = $self->get_department($hit->{tree}->[1]->{_id});
                #     $tree->{$layer2->{name}}->{$layer3->{name}}
                #         ->{$hit->{name}}->{id} = $hit->{tree}->[2]->{_id};
                #     $tree->{$layer2->{name}}->{$layer3->{name}}
                #         ->{$hit->{name}}->{display} = $hit->{display};
                # }
            }
        );

        return $tree;
}

sub get_file_store {
    my ($self) = @_;

    my $file_store = $self->config->{filestore}->{default}->{package};
    my $file_opts = $self->config->{filestore}->{default}->{options} // {};

    my $pkg
        = Catmandu::Util::require_package($file_store, 'LibreCat::FileStore');
    $pkg->new(%$file_opts);
}

sub get_access_store {
    my ($self) = @_;

    my $file_store = $self->config->{filestore}->{access}->{package};
    my $file_opts = $self->config->{filestore}->{access}->{options} // {};

    my $pkg
        = Catmandu::Util::require_package($file_store, 'LibreCat::FileStore');
    $pkg->new(%$file_opts);
}

sub uri_for {
    my ($self, $path, $uri_params) = @_;
    $uri_params ||= {};
    my $uri = $path . "?";
    foreach (keys %{$uri_params}) {
        $uri .= "$_=$uri_params->{$_}&";
    }
    $uri =~ s/&$//;    #delete trailing "&"
    $uri;
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
