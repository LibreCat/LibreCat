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
use LibreCat::I18N;
use LibreCat::Layers;
use LibreCat;
use Log::Log4perl ();
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
    my ($self,$file) = @_;

    $self->log->debug("searching for fix `$file'");

    for my $p (@{LibreCat->layers->fixes_paths}) {
        $self->log->debug("testing `$p/$file'");
        if (-r "$p/$file") {
            $self->log->debug("found `$p/$file'");
            return Catmandu::Fix->new( fixes => ["$p/$file"] );
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
    my $hits       = $self->search_publication($p);
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

sub get_person {
    my $hits;
    if ($_[1]) {
        $hits = $_[0]->search_researcher({q => ["id=$_[1]"]});
        $hits = $_[0]->search_researcher({q => ["login=$_[1]"]})
            if !$hits->{total};
    }
    return $hits->{hits}->[0] if $hits->{hits};
    return {error => "something went wrong"} if !$hits->{hits};
}

sub get_project {
    $_[0]->project->get($_[1]);
}

sub get_department {
    if ($_[1] && length $_[1]) {
        my $result = $_[0]->department->get($_[1]);
        $result = $_[0]->search_department({q => ["name=\"$_[1]\""]})->first
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

    my $hits = $self->search_publication(
        {q => ["status=public", "type<>research_data", "type<>data"]});
    my $reshits = $self->search_publication(
        {q => ["status=public", "(type=research_data OR type=data)"]});
    my $oahits = $self->search_publication(
        {
            q => [
                "status=public",      "fulltext=1",
                "type<>research_data", "type<>data"
            ]
        }
    );

    return {
        publications => $hits->{total},
        researchdata => $reshits->{total},
        oahits       => $oahits->{total},
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

sub default_facets {
    return {
        author      => {terms => {field => 'author.id',        size => 20,}},
        editor      => {terms => {field => 'editor.id',        size => 20,}},
        open_access => {terms => {field => 'file.open_access', size => 1}},
        popular_science => {terms => {field => 'popular_science', size => 1}},
        extern          => {terms => {field => 'extern',          size => 2}},
        status          => {terms => {field => 'status',          size => 8}},
        year            => {
            terms => {field => 'year', size => 100, order => 'reverse_term'}
        },
        type => {terms => {field => 'type', size => 25}},
        isi  => {terms => {field => 'isi',  size => 1}},
        pmid => {terms => {field => 'pmid', size => 1}},
    };
}

sub sort_to_sru {
    my ($self, $sort) = @_;

    my $cql_sort;
    if ($sort and ref $sort ne "ARRAY") {
        $sort = [$sort];
    }
    foreach my $s (@$sort) {
        if ($s =~ /(\w{1,})\.(asc|desc)/) {
            $cql_sort .= "$1,,";
            $cql_sort .= $2 eq "asc" ? "1 " : "0 ";
        }
        elsif ($s =~ /\w{1,},,(0|1)/) {
            $cql_sort .= $s;
        }
    }
    $cql_sort = trim($cql_sort);
    return $cql_sort;
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

sub search_publication {
    my ($self, $p) = @_;

    my $sort = $self->sort_to_sru($p->{sort});
    my $cql  = "";
    if ($p->{q}) {
        push @{$p->{q}}, "status<>deleted";
        $cql = join(' AND ', @{$p->{q}});
    }
    else {
        $cql = "status<>deleted";
    }

    my $hits;

    #$cql =~ tr/äöüß/aous/;

    try {
        $hits = publication->search(
            cql_query    => $cql,
            sru_sortkeys => $sort,
            limit => $p->{limit} ||= $self->config->{default_page_size},
            start  => $p->{start}  ||= 0,
            facets => $p->{facets} ||= {},
        );

        foreach (qw(next_page last_page page previous_page pages_in_spread)) {
            $hits->{$_} = $hits->$_;
        }
    }
    catch {
        my $error;
        if ($_ =~ /(cql error\: unknown index .*?) at/) {
            $error = $1;
        }
        else {
            $error = "An error has occurred: $_";
        }
        $hits = {total => 0, error => $error};
    };

    return $hits;
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

sub search_researcher {
    my ($self, $p) = @_;

    my $cql = "";
    $cql = join(' AND ', @{$p->{q}}) if $p->{q};

    my $hits = researcher->search(
        cql_query    => $cql,
        limit        => $p->{limit} ||= config->{maximum_page_size},
        start        => $p->{start} ||= 0,
        sru_sortkeys => $p->{'sort'} || "fullname,,1",
    );

    # if ($p->{get_person}) {
    #     my $personlist;
    #     foreach my $hit (@{$hits->{hits}}) {
    #         $personlist->{$hit->{_id}} = $hit->{full_name};
    #     }
    #     return $personlist;
    # }

    return $hits;
}

sub search_department {
    my ($self, $p) = @_;

    my $cql = "";
    $cql = join(' AND ', @{$p->{q}}) if $p->{q};

    if ($p->{hierarchy}) {
        my $hits = department->search(
            cql_query => $cql,
            limit     => config->{maximum_page_size},
            start     => 0,
        );

        my $hierarchy;
        $hits->each(
            sub {
                my $hit = $_[0];
                $hierarchy->{$hit->{name}}->{oId} = $hit->{tree}->[0]->{_id}
                    if $hit->{layer} eq "1";
                $hierarchy->{$hit->{name}}->{display} = $hit->{display}
                    if $hit->{layer} eq "1";
                if ($hit->{layer} eq "2") {
                    my $layer
                        = $self->get_department($hit->{tree}->[0]->{_id});
                    $hierarchy->{$layer->{name}}->{$hit->{name}}->{oId}
                        = $hit->{tree}->[1]->{_id};
                    $hierarchy->{$layer->{name}}->{$hit->{name}}->{display}
                        = $hit->{display};
                }
                if ($hit->{layer} eq "3") {
                    my $layer2
                        = $self->get_department($hit->{tree}->[0]->{_id});
                    my $layer3
                        = $self->get_department($hit->{tree}->[1]->{_id});
                    $hierarchy->{$layer2->{name}}->{$layer3->{name}}
                        ->{$hit->{name}}->{oId} = $hit->{tree}->[2]->{_id};
                    $hierarchy->{$layer2->{name}}->{$layer3->{name}}
                        ->{$hit->{name}}->{display} = $hit->{display};
                }
            }
        );

        return $hierarchy;
    }
    else {
        my $hits = department->search(
            cql_query    => $cql,
            limit        => $p->{limit} ||= 20,
            start        => $p->{start} ||= 0,
            sru_sortkeys => "display,,1",
        );
        return $hits;
    }
}

sub search_project {
    my ($self, $p) = @_;

    my $cql = "";
    $cql = join(' AND ', @{$p->{q}}) if $p->{q};

    if ($p->{hierarchy}) {
        $cql = $cql ? " AND funded=1" : "funded=1";
        my $hits = project->search(
            cql_query => $cql,
            limit     => config->{maximum_page_size},
            start     => 0,
        );

        my $hierarchy;
        $hits->each(
            sub {
                my $hit = $_[0];
                my $display
                    = $hit->{acronym}
                    ? $hit->{acronym} . " | " . $hit->{name}
                    : $hit->{name};
                $hierarchy->{$display}->{oId} = $hit->{id};
            }
        );

        return $hierarchy;
    }
    else {
        my $hits = project->search(
            cql_query    => $cql,
            limit        => $p->{limit} ||= config->{default_page_size},
            start        => $p->{start} ||= 0,
            sru_sortkeys => $p->{sorting} ||= "name,,1",
        );

        foreach (qw(next_page last_page page previous_page pages_in_spread)) {
            $hits->{$_} = $hits->$_;
        }

        return $hits;
    }

}

sub search_research_group {
    my ($self, $p) = @_;

    my $cql = "";
    $cql = join(' AND ', @{$p->{q}}) if $p->{q};

    if ($p->{hierarchy}) {
        my $hits = research_group->search(
            cql_query => $cql,
            limit     => config->{maximum_page_size},
            start     => 0,
        );

        my $hierarchy;
        $hits->each(
            sub {
                my $hit = $_[0];
                my $display
                    = $hit->{acronym}
                    ? $hit->{acronym} . " | " . $hit->{name}
                    : $hit->{name};
                $hierarchy->{$display}->{oId} = $hit->{_id};
            }
        );

        return $hierarchy;
    }
    else {
        my $hits = research_group->search(
            cql_query    => $cql,
            limit        => $p->{limit} ||= config->{default_page_size},
            start        => $p->{start} ||= 0,
            sru_sortkeys => $p->{sort} ||= "name,,1",
        );

        foreach (qw(next_page last_page page previous_page pages_in_spread)) {
            $hits->{$_} = $hits->$_;
        }

        return $hits;
    }

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
