package LibreCat::Cmd::generate;

use Catmandu::Sane;
use Path::Tiny;
use Template;
use LibreCat::App::Helper;
use LibreCat qw(:self);
use Carp;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat generate package.json
librecat generate forms
librecat generate departments
librecat generate cleanup

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/^(package\.json|forms|departments|cleanup)$/;

    unless (@$args) {
        $self->usage_error("should be one of $commands");
    }

    my $cmd = shift @$args;

    unless ($cmd =~ /^$commands$/) {
        $self->usage_error("should be one of $commands");
    }

    if ($cmd eq 'package.json') {
        return $self->_generate_package_json;
    }
    elsif ($cmd eq 'forms') {
        return $self->_generate_forms;
    }
    elsif ($cmd eq 'departments') {
        return $self->_generate_departments;
    }
    elsif ($cmd eq 'cleanup') {
        return $self->_generate_cleanup;
    }
}

sub _helper {
    $_[0]->{helper} ||= LibreCat::App::Helper::Helpers->new();
}

sub _generate_cleanup {
    print "Cleaning generated forms...\n";
    {
        my $template_paths = librecat->template_paths;
        my $forms_path     = $template_paths->[0] . '/backend/forms';

        print "$forms_path\n";

        unlink glob("$forms_path/*.tt");

        my $admin_path = $template_paths->[0] . '/admin/forms';

        print "$admin_path\n";

        unlink glob("$admin_path/*.tt");
    }

    print "Cleaning departments...\n";
    {
        my $template_paths = librecat->template_paths;

        my $output_path = $template_paths->[0] . '/department';

        if (-f "$output_path/nodes.tt") {
            print "$output_path/nodes.tt\n";
            unlink "$output_path/nodes.tt";
        }

        if (-f "$output_path/nodes_backend.tt") {
            print "$output_path/nodes_backend.tt\n";
            unlink "$output_path/nodes_backend.tt";
        }
    }

    return 0;
}

sub _generate_package_json {
    my $css_path       = librecat->css_paths->[0];
    my $root_css_path  = librecat->css_paths->[-1];
    my $scss_path      = librecat->scss_paths->[0];
    my $root_scss_path = librecat->scss_paths->[-1];
    my $main_css       = path($css_path)->child('main.css')->stringify;
    my $root_main_css  = path($root_css_path)->child('main.css')->stringify;
    my $main_scss      = path($scss_path)->child('main.scss')->stringify;
    my $root_main_scss = path($root_scss_path)->child('main.scss')->stringify;
    my $package_json
        = path(librecat->root_path)->child('package.json')->stringify;

    my $json = {
        "name"         => "librecat",
        "dependencies" => {
            "autoprefixer"   => "^6.3.7",
            "bootstrap-sass" => "3.3.7",
            "node-sass"      => "^3.8.0",
            "nodemon"        => "^1.9.2",
            "npm-run-all"    => "^2.3.0",
            "postcss"        => "^5.0.21",
            "postcss-cli"    => "^2.5.2",
        },
        "scripts" => {
            "build-core-css-dev" =>
                "node-sass --source-map true $root_main_scss $root_main_css",
            "build-core-css" =>
                "node-sass --output-style compressed $root_main_scss $root_main_css",
            "build-css-dev" =>
                "node-sass --source-map true $main_scss $main_css",
            "build-css" =>
                "node-sass --output-style compressed $main_scss $main_css",
            "prefix-core-css" =>
                "postcss -u autoprefixer --autoprefixer.browsers '> 5%' -o $root_main_css $root_main_css",
            "prefix-css" =>
                "postcss -u autoprefixer --autoprefixer.browsers '> 5%' -o $main_css $main_css",
            "core-css-dev" =>
                "nodemon -e $root_scss_path -x 'node_modules/.bin/npm-run-all build-core-css-dev prefix-core-css'",
            "core-css" =>
                "nodemon -e $root_scss_path -x 'node_modules/.bin/npm-run-all build-core-css prefix-core-css'",
            "css-dev" =>
                "nodemon -e $scss_path -x 'node_modules/.bin/npm-run-all build-css-dev prefix-css'",
            "css" =>
                "nodemon -e $scss_path -x 'node_modules/.bin/npm-run-all build-css prefix-css'",
        },
    };

    my $exporter = Catmandu->exporter(
        'JSON',
        file   => $package_json,
        pretty => 1,
        array  => 0
    );
    $exporter->add($json);
    $exporter->commit;

    print "created: $package_json\n";

    return 0;
}

sub _generate_forms {
    my $h              = $_[0]->_helper;
    my $conf           = $h->config;
    my $forms          = $conf->{forms}{publication_types};
    my $other_items    = $conf->{forms}{other_items};
    my $template_paths = librecat->template_paths;
    my $output_path    = $template_paths->[0] . '/backend/forms';

    #-----------------

    print "[$output_path]\n";
    my $tt = Template->new(
        START_TAG    => '{%',
        END_TAG      => '%}',
        ENCODING     => 'utf8',
        INCLUDE_PATH => [map {"$_/backend/generator"} @$template_paths],
        OUTPUT_PATH  => $output_path,
    );

    foreach my $type (keys %$forms) {
        my $type_hash = $forms->{$type};
        $type_hash->{field_order} = $conf->{forms}{field_order};
        if ($type_hash->{fields}) {
            print "Generating $output_path/$type.tt\n";
            $tt->process("master.tt", $type_hash, "$type.tt")
                || die $tt->error(), "\n";
        }
    }

    #-----------------

    $output_path = $template_paths->[0] . '/admin/forms';

    print "[$output_path]\n";

    my $tta = Template->new(
        START_TAG    => '{%',
        END_TAG      => '%}',
        ENCODING     => 'utf8',
        INCLUDE_PATH => [map {"$_/admin/generator"} @$template_paths],
        OUTPUT_PATH  => $output_path,
    );

    foreach my $item (keys %$other_items) {
        print "Generating $output_path/edit_$item page\n";
        $tta->process("master_$item.tt", $other_items->{$item},
            "edit_$item.tt")
            || die $tta->error(), "\n";
    }

    return 0;
}

sub _generate_departments {
    my ($self, $file) = @_;
    my $h = $self->_helper;

    my $template_paths = librecat->template_paths;
    my $output_path    = $template_paths->[0] . '/department';

    my $pubs = $h->publication;
    my $it   = Catmandu->store('main')->bag('department');

    my $HASH = {};

    $it->each(
        sub {
            my ($item) = @_;

            my $tree = $item->{tree} // [];

            my $root = $HASH;

            my @reversed = reverse @$tree;

            for my $node (@reversed) {
                my $id = $node->{_id};

                $root->{tree}->{$id} //= {};

                $root = $root->{tree}->{$id};
            }

            my $id = $item->{_id};

            return unless defined($id) && $id =~ /\S+/;

            my $hits
                = $pubs->search(cql_query =>
                    "department=$id AND status=public"
                );
            my $total = $hits->{total};

            $root->{tree}->{$id}->{name}    = $item->{name};
            $root->{tree}->{$id}->{display} = $item->{display};
            $root->{tree}->{$id}->{total}   = $total;

            print STDERR "Adding $id ($total)\n";
        }
    );

    path($output_path)->mkpath unless -d $output_path;

    open(my $fh, '>:encoding(UTF-8)', "$output_path/nodes.tt")
        || die "failed to write nodes.tt: $!";

    $self->_template_printer($HASH, "publication", $fh);

    close($fh);

    print STDERR "Output written to $output_path/nodes.tt\n";

    open($fh, '>:encoding(UTF-8)', "$output_path/nodes_backend.tt")
        || die "failed to write nodes_backend.tt : $!";

    $self->_template_printer($HASH, "librecat", $fh);

    close($fh);

    print STDERR "Output written to $output_path/nodes_backend.tt\n";

    return 0;
}

sub _template_printer {
    my ($self, $tree, $path, $io) = @_;

    my $nodes = $tree->{tree};
    return unless $nodes;

    my $uri_base = $self->_helper->uri_base;

    print $io "<ul>\n";
    for my $node (sort {$nodes->{$a}->{name} cmp $nodes->{$b}->{name}}
        keys %$nodes)
    {
        print $io "<li>\n";
        printf $io "<a href=\"${uri_base}/%s?cql=department=%s\">%s</a> %d\n",
            $path, $node, $nodes->{$node}->{display},
            $nodes->{$node}->{total};
        $self->_template_printer($nodes->{$node}, $path, $io);
        print $io "</li>\n";
    }
    print $io "</ul>\n";
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::generate - generate various files

=head1 SYNOPSIS

    librecat generate package.json
    librecat generate forms
    librecat generate departments
    librecat generate cleanup

=cut
