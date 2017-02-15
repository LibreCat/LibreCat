use strict;
use warnings FATAL => 'all';
use Template;
use Path::Class;
use Test::More;

sub file_index {
    my @files;
    dir('./views')->recurse(callback => sub {
        my $file = shift;
        if($file =~ /\.tt$/) {
            push @files, $file->absolute->stringify;
        }
    });

    return \@files;
}

sub create_template_test {
    my $tmpl = shift;

    my $tt = Template->new({
        ABSOLUTE => 1,
        INCLUDE_PATH => './views',
    });

    my $vars;
    my $output;
    unless ($tmpl =~ /generator/) {
        if ( !ok( $tt->process( $tmpl, $vars, \$output ), $tmpl ) ) {
            diag( $tt->error );
        }
    }
}

foreach my $tmpl ( @{file_index()} ) {
    create_template_test($tmpl);
}

done_testing;
