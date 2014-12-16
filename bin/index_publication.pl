#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension);

use Catmandu::Sane;
use Catmandu -all;
use Catmandu::Fix
    qw(add_ddc rename_relations move_field split_ext_ident add_contributor_info add_file_access language_info remove_field volume_sort);

use SBCatDB;
use luurCfg;
use Getopt::Std;
use Orms;

getopts('u:m:i:');
our $opt_u;

# m for multiple indices
our $opt_m;
our $opt_i;

my $cfg  = luurCfg->new;
my $orm  = $cfg->{ormsCfg};
my $luur = Orms->new( $cfg->{ormsCfg} );

my $home = $ENV{BACKEND};

my $index_name = "backend";
if ( $opt_m ) {
    if ($opt_m eq "backend1" || $opt_m eq "backend2" ) {
    	$index_name = $opt_m;
    } else {
    	die "$opt_m is not an valid option";
    }
}

Catmandu->load(':up');
my $conf = Catmandu->config;

my $pre_fixer = Catmandu::Fix->new(
    fixes => [

        #            'add_citation()',
        'rename_relations()',
        'add_contributor_info()',
        'split_ext_ident()',
        'move_field("type.typeName","documentType")',
        'add_file_yearlastuploaded()',
        'add_field_yearcreated()',
        'add_file_access()',
        'language_info()',
        'add_ddc()',
        'volume_sort()',
    ]
);

my $post_fixer = Catmandu::Fix->new(
    fixes => [
        'remove_field("type")',          'remove_field("usesLanguage")',
        'remove_field("citations._id")', 'remove_field("message")',
        'hiddenFor_info()',              'schema_dot_org()',
    ]
);

my $separate_fixer = Catmandu::Fix->new(
    fixes => [ 'remove_field("additionalInformation")', ] );

my $bag    = Catmandu->store('search', index_name => $index_name)->bag('publication');
my $citbag = Catmandu->store('citation')->bag;
my $authors;

my $db = SBCatDB->new(
    {   config_file => "/srv/www/sbcat/conf/extension/sbcatDb.pl",
        db_name     => $orm->{ormsDb},
        host        => $orm->{ormsDbHost},
        username    => $orm->{ormsDbUser},
        password    => $orm->{ormsDbPassword},
    }
);

sub add_to_index {
    my $rec = shift;

    $pre_fixer->fix($rec);
    $rec->{citation} = $citbag->get( $rec->{_id} ) if $rec->{_id};
    $post_fixer->fix($rec);

    ( $rec->{project} ) && ( $rec->{proj} = 1 );

    if ( $rec->{documentType} ne 'researchData' ) {
        $separate_fixer->fix($rec);
    }

    $bag->add($rec);
}

if ($opt_i) {
    my $q       = "id=$opt_i";
    my $results = $db->find($q);
    while ( my $rec = $results->next ) {

        if ( $rec->{isAuthoredBy} ) {
            foreach ( @{ $rec->{isAuthoredBy} } ) {
                if ( $_->{personNumber} ) {
                    $authors->{ $_->{personNumber} } = "true";
                }
            }
        }

        if ( $rec->{isEditedBy} ) {
            foreach ( @{ $rec->{isEditedBy} } ) {
                if ( $_->{personNumber} ) {
                    $authors->{ $_->{personNumber} } = "true";
                }
            }

        }

        $pre_fixer->fix($rec);
        $rec->{citation} = $citbag->get( $rec->{_id} ) if $rec->{_id};
        $post_fixer->fix($rec);

        if ( $rec->{documentType} ne "researchData" ) {
            $separate_fixer->fix($rec);
        }

        $bag->add($rec);
        $bag->commit;

        if ($authors) {
            foreach my $key ( keys %$authors ) {
                `/srv/www/app-catalog/bin/index_researcher.pl -i $key`;
            }
            $authors = ();
        }

        exit;
    }
}

if ($opt_u) {    # update process

    my $q       = "dateLastChanged > \"$opt_u\"";
    my $results = $db->find($q);
    while ( my $rec = $results->next ) {
        if ( $rec->{isAuthoredBy} ) {
            foreach ( @{ $rec->{isAuthoredBy} } ) {
                if ( $_->{personNumber} ) {
                    $authors->{ $_->{personNumber} } = "true";
                }
            }
        }
        if ( $rec->{isEditedBy} ) {
            foreach ( @{ $rec->{isEditedBy} } ) {
                if ( $_->{personNumber} ) {
                    $authors->{ $_->{personNumber} } = "true";
                }
            }
        }
        add_to_index($rec);
    }

}
else {    # initial indexing

    # get all publication types
    my $types = $luur->getChildrenTypes( type => 'publicationItem' );

    # foreach type get public records
    foreach (@$types) {

        my $obj = $luur->getObjectsByType( type => $_ );
        foreach (@$obj) {
            my $rec = $db->get($_);
            if (    $rec->{submissionStatus}
                and $rec->{submissionStatus} ne "pdeleted" )
            {
                add_to_index($rec);
            }
        }
    }

}

$bag->commit;

if ($authors) {
    foreach my $key ( keys %$authors ) {
        if ($opt_m) {
            `./index_researcher.pl -m $opt_m -i $key`;
        }
        else {
            `./index_researcher.pl -i $key`;
        }
    }
    $authors = ();
}

=head1 SYNOPSIS

	Script for indexing publication data

=head2 Initial indexing

	perl index_publication.pl

# fetches all data from SBCatDB and pushes it into the search store

=head2 Update process

perl index_publication.pl -u 'DATETIME'

# fetches all records with dateLastChanged > 'DATETIME' (e.g. 2012-10-15 21:34:02) and pushes it into the search store

=cut
