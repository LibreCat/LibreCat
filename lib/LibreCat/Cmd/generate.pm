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
    my $layers       = Catmandu::CLI->layers;
    my $css_path     = $layers->css_paths->[0];
    my $scss_path    = $layers->scss_paths->[0];
    my $main_css     = path($css_path)->child('main.css')->stringify;
    my $main_scss    = path($scss_path)->child('main.scss')->stringify;
    my $package_json = path($layers->root_path)->child('package.json')->stringify;

    my $json = {
      "name" => "librecat",
      "version" => "$LibreCat::VERSION",
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
        "build-css-dev" => "node_modules/.bin/node-sass --source-map true $main_scss $main_css",
        "build-css" => "node_modules/.bin/node-sass --output-style compressed $main_scss $main_css",
        "prefix-css" => "node_modules/.bin/postcss -u autoprefixer --autoprefixer.browsers '> 5%' -o $main_css $main_css",
        "css-dev" => "node_modules/.bin/nodemon -e $scss_path -x 'node_modules/.bin/npm-run-all build-css-dev prefix-css'",
        "css" => "node_modules/.bin/nodemon -e $scss_path -x 'node_modules/.bin/npm-run-all build-css prefix-css'",
      },
    };

    my $exporter = Catmandu->exporter('JSON', file => $package_json, pretty => 1);
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
