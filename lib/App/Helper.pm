package App::Helper::Helpers;

use FindBin;
use Catmandu::Sane;
use Catmandu qw(:load export_to_string);
use Catmandu::Util qw(:io :is :array :hash :human trim);
use Catmandu::Fix qw(expand);
use Catmandu::Store::DBI;
use Dancer qw(:syntax vars params request);
use Dancer::FileUtils qw(path);
use POSIX qw(strftime);
use JSON::MaybeXS qw(encode_json);
use Moo;

# TODO is this needed anymore?
sub config {
    state $config;

    # Required to load Catmandu at run time to for the Dancer::Test framework
    unless ($config) {
        Catmandu->load("$FindBin::Bin/..");
        $config = hash_merge(Catmandu->config, Dancer::config);
    }
    $config;
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

sub backup_award {
    state $bag = Catmandu->store('backup')->bag('award');
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

sub award {
    state $bag = Catmandu->store('search')->bag('award');
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

    $params ||= params;
    foreach my $k (keys %$params) {
        unless (defined $params->{$k}) {
            delete $params->{$k};
            next;
        }
        delete $params->{$k} if ($params->{$k} =~ /^$/);
    }
    my $fixer = Catmandu::Fix->new(fixes => ["expand()"]);
    return $fixer->fix($params);
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
                    =~ /((?=AND |OR |NOT )?[0-9a-zA-Z]+\=\s|(?=AND |OR |NOT )?[0-9a-zA-Z]+\=$)/g
            )
            )
        {
            $cql
                =~ s/((AND |OR |NOT )?[0-9a-zA-Z]+\=\s|(AND |OR |NOT )?[0-9a-zA-Z]+\=$)/ /g;
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
            !~ /^("[^"]*"|'[^']*'|[0-9a-zA-Z]+(=| ANY | ALL | EXACT )"[^"]*")$/
            and $cql
            !~ /^(([0-9a-zA-Z]+\=(?:[0-9a-zA-Z\-\*]+|"[^"]*"|'[^']*')+\**(?<!AND)(?<!OR)(?<!ANY)(?<!ALL)(?<!EXACT)|"[^"]*"|'[^']*') (AND|OR) ([0-9a-zA-Z]+\=(?:[0-9a-zA-Z\-\*]+|"[^"]*"|'[^']*')+\**(?<!AND)(?<!OR)|"[^"]*"|'[^']*'))$/
            and $cql
            !~ /^(([0-9a-zA-Z]+( ANY | ALL | EXACT )"[^"]*"|"[^"]*"|'[^']*'|[0-9a-zA-Z]+\=(?:[0-9a-zA-Z\-\*]+|"[^"]*"|'[^']*')+\**(?<!AND)(?<!OR))( (AND|OR) (([0-9a-zA-Z]+( ANY | ALL | EXACT )"[^"]*")|"[^"]*"|'[^']*'|[0-9a-zA-Z]+\=(?:[0-9a-zA-Z\-\*]+|"[^"]*"|'[^']*')+\**))*)$/
            )
        {
            $cql
                =~ s/((?:(?:(?:[0-9a-zA-Z\=\-\*]+(?<!AND)(?<!OR)|"[^"]*"|'[^']*') (?:AND|OR) )+(?:[0-9a-zA-Z\=\-\*]+(?<!AND)(?<!OR)|"[^"]*"|'[^']*'))|[0-9a-zA-Z\=\-\*]+(?<!AND)(?<!OR)|"[^"]*"|'[^']*')\s(?!AND )(?!OR )("[^"]*"|'[^']*'|.*?)/$1 AND $2/g;
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
    my $now = strftime($_[0]->config->{time_format}, gmtime(time));
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
    if ($_[1] and is_integer $_[1]) {
        $hits = $_[0]->search_researcher({q => ["id=$_[1]"]});
    }
    elsif ($_[1] and is_string $_[1]) {
        $hits = $_[0]->search_researcher({q => ["login=$_[1]"]});
    }
    return $hits->{hits}->[0] if $hits->{hits};
    return {error => "something went wrong"} if !$hits->{hits};
}

sub get_award {
    $_[0]->award->get($_[1]);
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
        {q => ["status=public", "type<>researchData", "type<>dara"]});
    my $reshits = $self->search_publication(
        {q => ["status=public", "(type=researchData OR type=dara)"]});
    my $oahits = $self->search_publication(
        {
            q => [
                "status=public",      "fulltext=1",
                "type<>researchData", "type<>dara"
            ]
        }
    );
    my $disshits
        = $self->search_publication({q => ["status=public", "type=bi*"]});
    my $people = $self->search_researcher({q => ["publcount>0"]});

    return {
        publications => $hits->{total},
        researchdata => $reshits->{total},
        oahits       => $oahits->{total},
        theseshits   => $disshits->{total},
        pubpeople    => $people->{total},
    };

}

sub get_metrics {
    my ($self, $bag, $id) = @_;
    return {} unless $bag and $id;

    if ($bag eq 'oa_stats') {
        return Catmandu->store('metrics')->bag($bag)
            ->select("identifier", "oai:pub.uni-bielefeld.de:$id")->to_array;
    }

    return Catmandu->store('metrics')->bag($bag)->get($id);
}

sub new_record {
    my ($self, $bag) = @_;

    my $id = "";

    if ($bag eq "project") {
        my $arr_ref;
        @$arr_ref
            = sort {$b->{_id} cmp $a->{_id}} @{$self->project->to_array()};

        if (@$arr_ref > 0) {
            $id = $arr_ref->[0]->{_id};
            $id =~ s/^P//g;
            $id++;
            $id = "P" . $id;
        }
        else {
            $id = "P1";
        }
    }
    elsif ($bag eq "research_group") {
        my $arr_ref;
        @$arr_ref = sort {$b->{_id} cmp $a->{_id}}
            @{$self->research_group->to_array()};

        if (@$arr_ref > 0) {
            $id = $arr_ref->[0]->{_id};
            $id =~ s/^RG//g;
            $id++;
            $id = "RG" . $id;
        }
        else {
            $id = "RG1";
        }
    }
    else {
        # TODO race condition!
        Catmandu->store->transaction(
            sub {
                my $rec = $self->bag->get_or_add('1', {latest => '0'});
                $id = ++$rec->{latest};
                $self->bag->add($rec);
            }
        );
    }

    return $id;
}

sub update_record {
    my ($self, $bag, $rec) = @_;

    # don't know where to put it, should find better place to handle this
    # especially the async stuff
    if ($bag eq 'publication') {

        require App::Catalogue::Controller::File;
        require App::Catalogue::Controller::Material;
        ($rec->{file})
            && ($rec->{file}
            = App::Catalogue::Controller::File::handle_file($rec));

        foreach my $f (@{$rec->{file}}) {
            if ($f->{access_level} eq 'open_access'
                && lc $f->{file_name} =~ /\.pdf$|\.ps$/)
            {
                App::Catalogue::Controller::File::make_thumbnail($rec->{_id},
                    $f->{file_name});
                last;
            }
        }
        if ($rec->{related_material}) {
            App::Catalogue::Controller::Material::update_related_material(
                $rec);
        }
    }

    Catmandu::Fix->new(fixes => [join_path('fixes', "update_$bag.fix")])
        ->fix($rec);
    my $bagname = "backup_$bag";
    my $saved   = $self->$bagname->add($rec);

    #compare version! through _version or through date_updated
    $self->$bag->add($saved);
    $self->$bag->commit;

    sleep 1;    #bad hack!

    return $saved;
}

sub delete_record {
    my ($self, $bag, $id) = @_;

    my $del = {_id => $id, date_deleted => $self->now, status => 'deleted',};

    if ($bag eq 'publication') {
        my $rec = $self->publication->get($id);
        $del->{date_created} = $rec->{date_created};
        $del->{oai_deleted}  = 1
            if ($rec->{oai_deleted} or $rec->{status} eq 'public');
        require App::Catalogue::Controller::File;
        require App::Catalogue::Controller::Material;
        App::Catalogue::Controller::Material::update_related_material($del);
        App::Catalogue::Controller::File::delete_file($id);
        delete $del->{related_material};
    }

    my $bagname = "backup_$bag";
    my $saved   = $self->$bagname->add($del);
    $self->$bag->add($saved);
    $self->$bag->commit;

    sleep 1;

    return $saved;
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
    $cql =~ tr/äöüß/aous/;

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

    foreach (qw(next_page last_page page previous_page pages_in_spread)) {
        $hits->{$_} = $hits->$_;
    }

    if ($p->{get_person}) {
        my $personlist;
        foreach my $hit (@{$hits->{hits}}) {
            $personlist->{$hit->{_id}} = $hit->{full_name};
        }
        return $personlist;
    }

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

sub search_award {
    my ($self, $p) = @_;

    my $hits = award->search(
        cql_query => $p->{q},
        limit     => $p->{limit} ||= config->{default_page_size},
        facets    => $p->{facets} ||= {},
        start     => $p->{start} ||= 0,
    );

    return $hits;
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

sub newuri_for {
    my ($self, $path, $uri_params, $passedparam) = @_;
    my $passed_key;
    my $passed_value;
    foreach (keys %{$passedparam}) {
        $passed_key   = $_;
        $passed_value = $passedparam->{$_};
    }

    my $uri = $path . "?";

    $uri_params = () if $uri_params eq "";

    if (defined $uri_params->{$passed_key}) {
        foreach my $urikey (keys %{$uri_params}) {
            if ($urikey ne $passed_key) {
                next if $urikey eq "start";
                if (ref $uri_params->{$urikey} eq 'ARRAY') {
                    foreach (@{$uri_params->{$urikey}}) {
                        $uri .= "$urikey=$_&";
                    }
                }
                elsif ($uri_params->{$urikey}) {
                    $uri .= "$urikey=$uri_params->{$urikey}&";
                }
            }
            else {    # $urikey eq $passed_key
                if (   $passed_key eq "person"
                    or $passed_key eq "author"
                    or $passed_key eq "editor"
                    or $passed_key eq "publicationtype"
                    or $passed_key eq "publishingyear"
                    or $passed_key eq "sort")
                {
                    if (ref $uri_params->{$urikey} eq 'ARRAY') {
                        foreach (@{$uri_params->{$urikey}}) {
                            if ($passed_value ne "") {
                                if (
                                    $passed_value !~ /^del_.*/
                                    or (    $passed_value =~ /^del_(.*)/
                                        and $_ ne $1)
                                    )
                                {
                                    $uri .= "$urikey=$_&";
                                }
                            }

                        }
                    }
                    else {
                        $uri .= "$urikey=$uri_params->{$urikey}&"
                            unless $passed_value eq "";
                    }
                    $uri .= "$passed_key=$passed_value&"
                        unless $passed_value eq ""
                        or $passed_value =~ /^del_.*/;
                }
                else {
                    $uri .= "$passed_key=$passed_value&"
                        unless $passed_value eq "";
                }
            }
        }
    }
    else {
        foreach my $urikey (keys %{$uri_params}) {
            next if $urikey eq "start";
            if (ref $uri_params->{$urikey} eq 'ARRAY') {
                foreach (@{$uri_params->{$urikey}}) {
                    $uri .= "$urikey=$_&";
                }
            }
            elsif ($uri_params->{$urikey}) {
                $uri .= "$urikey=$uri_params->{$urikey}&";
            }
        }
        $uri .= "$passed_key=$passed_value&";
    }

    $uri =~ s/&$//;
    $uri;
}

sub is_portal_default {
    my ($self, $portal_name) = @_;

    # get portal default from config
    my $portal = $self->config->{portal}->{$portal_name};

    # get params from web
    my $p = $self->extract_params();

    my $return_hash;
    my $default_query;
    my $full_query;

    # Create default portal query hash
    foreach my $key (keys %$portal) {
        if ($key ne "q") {
            $default_query->{$key} = $portal->{$key};
            $full_query->{$key}    = $portal->{$key};
        }
        else {
            foreach my $entry (@{$portal->{q}}) {
                my $q;
                if (ref $entry->{or} eq "ARRAY") {
                    $q = "(" . join(" OR ", @{$entry->{or}}) . ")";
                }
                else {
                    $q = $entry->{or};
                }
                push @{$default_query->{q}},
                    $entry->{param} . $entry->{op} . $q;
                push @{$full_query->{q}}, $entry->{param} . $entry->{op} . $q;
            }
        }
        $return_hash->{default_query} = $default_query;
    }

    if (!$p) {

        # if no params, it must be the default portal query root
        $return_hash->{'default'} = 1;
    }
    else {
        foreach my $key (keys %$p) {

            # look at each key in the query, q is the hardest to handle
            if ($key eq "q") {
                foreach my $query (@{$p->{q}}) {

                    # in case the query comes as one q, split it
                    # so we can check the parts separately
                    my @parts = split(' AND ', $query);

                    # usually this will only be one $part
                    foreach my $part (@parts) {

             # get the three different parts of the query
             # parameter (e.g. "department"), operator (e.g. "=") and value(s)
                        if (
                            lc $part
                            =~ /^(\w{1,})(<=|>=|=|<|>|<>| exact | all | any | within )(.*)$/
                            )
                        {
                   # check if each of the three parts is in the portal default
                   # First the parameter
                            my $param
                                = grep {$1 eq $_->{param}} @{$portal->{q}};

                            # Second the operator
                            my $op = grep {$2 eq $_->{op}} @{$portal->{q}};

# Third all values (be careful: several values will be joined by OR and
# enclosed in parentheses, a single value won't be in array form in the config
# and won't be enclosed in parentheses)
                            my $val = grep {
                                my $or
                                    = ref $_->{or} eq "ARRAY"
                                    ? join(' OR ', @{$_->{or}})
                                    : $_->{or};
                                $or = "(" . $or . ")"
                                    if ref $_->{or} eq "ARRAY";
                                $3 eq $or
                            } @{$portal->{q}};

         # e.g. if there is no parameter "department", this is not part of the
         # default query, so add it to the return params that may be deletable
                            if (!$param) {
                                push @{$return_hash->{delete_them}->{q}},
                                    $part;
                            }

       # e.g. if there IS a parameter "department" but the operator is not "="
       # but "<>", this is not part of the default query
                            elsif (!$op) {
                                push @{$return_hash->{delete_them}->{q}},
                                    $part;
                            }

           # e.g. if there IS a parameter "department" AND the operator IS "="
           # but the values don't match, this is not part of the default query
                            elsif (!$val) {
                                push @{$return_hash->{delete_them}->{q}},
                                    $part;
                            }
                        }
                        else {
                            push @{$return_hash->{delete_them}->{q}}, $part;
                        }
                    }
                }
            }

            # all other keys are easy
            else {
# if the key doesn't exist in the portal config, it's not default query
# if the key DOES exist but the value does not match, it's not default query either
                if (!$portal->{$key}
                    or ($portal->{$key} and $portal->{$key} ne $p->{$key}))
                {
                    $return_hash->{delete_them}->{$key} = $p->{$key};
                }
            }
        }
    }

    if ($return_hash->{delete_them}) {
        foreach my $key (keys %{$return_hash->{delete_them}}) {
            if ($key eq "q") {
                foreach my $q (@{$return_hash->{delete_them}->{q}}) {
                    push @{$full_query->{q}}, $q;
                }
            }
            else {
                $full_query->{$key} = $return_hash->{delete_them}->{$key};
            }
        }
    }

    $return_hash->{full_query} = $full_query;

    return $return_hash;
}

package App::Helper;

my $h = App::Helper::Helpers->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook);
use Dancer::Plugin;

register h => sub {$h};

hook before_template => sub {

    $_[0]->{h} = $h;

};

register_plugin;

1;
