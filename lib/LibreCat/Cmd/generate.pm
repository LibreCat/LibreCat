package LibreCat::Cmd::generate;

use Catmandu::Sane;
use Catmandu;
use LibreCat;
use LibreCat::CLI;
use Path::Tiny;
use parent qw(LibreCat::Cmd);

sub description {
    return <<EOF;
Usage:

librecat generate package.json

EOF
}

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $commands = qr/package\.json/;

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
}

sub _generate_package_json {
    my $layers = LibreCat::CLI->layers;
    my $css_path = $layers->css_paths->[0];
    my $root_css_path = $layers->css_paths->[-1];
    my $scss_path = $layers->scss_paths->[0];
    my $root_scss_path = $layers->scss_paths->[-1];
    my $main_css = path($css_path)->child('main.css')->stringify;
    my $root_main_css = path($root_css_path)->child('main.css')->stringify;
    my $main_scss = path($scss_path)->child('main.scss')->stringify;
    my $root_main_scss = path($root_scss_path)->child('main.scss')->stringify;
    my $package_json = path($layers->root_path)->child('package.json')->stringify;

    my $json = {
      "name" => "librecat",
      "dependencies" => {
        "autoprefixer" => "^6.3.7",
        "bootstrap-sass" => "3.3.7",
        "node-sass" => "^3.8.0",
        "nodemon" => "^1.9.2",
        "npm-run-all" => "^2.3.0",
        "postcss" => "^5.0.21",
        "postcss-cli" => "^2.5.2",
      },
      "scripts" => {
        "build-core-css-dev" => "node-sass --source-map true $root_main_scss $root_main_css",
        "build-core-css" => "node-sass --output-style compressed $root_main_scss $root_main_css",
        "build-css-dev" => "node-sass --source-map true $main_scss $main_css",
        "build-css" => "node-sass --output-style compressed $main_scss $main_css",
        "prefix-css" => "postcss -u autoprefixer --autoprefixer.browsers '> 5%' -o $main_css $main_css",
        "core-css-dev" => "nodemon -e $root_scss_path -x 'node_modules/.bin/npm-run-all build-core-css-dev prefix-css'",
        "core-css" => "nodemon -e $root_scss_path -x 'node_modules/.bin/npm-run-all build-core-css prefix-css'",
        "css-dev" => "nodemon -e $scss_path -x 'node_modules/.bin/npm-run-all build-css-dev prefix-css'",
        "css" => "nodemon -e $scss_path -x 'node_modules/.bin/npm-run-all build-css prefix-css'",
      },
    };

    my $exporter = Catmandu->exporter('JSON', file => $package_json, pretty => 1, array => 0);
    $exporter->add($json);
    $exporter->commit;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::generate - generate various files

=head1 SYNOPSIS

    librecat generate package.json

=cut
