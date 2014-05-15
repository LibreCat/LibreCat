#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/app-catalog/lib);

use Catmandu::Sane;
use Catmandu -all;
use Catmandu::Fix
    qw(add_ddc rename_relation remove_array_field move_field split_ext_ident add_contributor_info add_file_access language_info remove_field volume_sort);

#use MDS;
use SBCatDB;
use luurCfg;
use Getopt::Std;
use Orms;
use Data::Dumper;

getopts('u:m:i:');
our $opt_u;

# m for multiple indices
our $opt_m;
our $opt_i;

my $cfg  = luurCfg->new;
my $orm  = $cfg->{ormsCfg};
my $luur = Orms->new( $cfg->{ormsCfg} );

my $home = "/srv/www/app-catalog/";    #$ENV{BACKEND};

if ( $opt_m && $opt_m eq "backend2" ) {
    Catmandu->load("$home/index2");
}
elsif ( $opt_m && $opt_m eq "backend1" ) {
    Catmandu->load("$home/index1");
}
else {
    Catmandu->load($home);
}

my $conf = Catmandu->config;

my $pre_fixer = Catmandu::Fix->new(
    fixes => [
        'rename_relation()',
        'move_field("oId","_id")',
        'move_field("type.typeName","type")',
        'move_field("mainTitle", "title")',
        'move_field("alternativeTitle", "alternative_title")',
        'move_field("publishingYear", "year")',
        'move_field("dateLastChanged", "date_updated")',
        'move_field("pagesStart","page.start")',
        'move_field("pagesEnd", "page.end")',
        'move_field("pagesCount", "page.count")',
        'move_field("submissionStatus", "status")',
        'move_field("publicationStatus", "publication_status")',
        'move_field("usesOriginalLanguage.languageCode", "language")',
        'move_field("dateCreated", "date_created")',
        'move_field("record_creator.login", "tmp.record_creator")',
        'remove_field("record_creator")',
        'move_field("tmp.record_creator", "record_creator)',
        'move_field("doi.doi", "tmp.doi")';
        'remove_field("doi")',
        'move_field("tmp.doi", "doi")',
        'move_field("isNonLuPublication", "extern")',
        'move_field("hasDdc.ddcNumber", "ddc")',
        'move_field("eIssn", "eissn")',
        'move_field("dateSubmitted", "date_submitted")',

        'add_contributor_info()',
        'split_ext_ident()',
        'move_identifiers()',

        #'add_file_yearlastuploaded()',
        #'add_field_yearcreated()',
        'add_file_access()',
        'clean_language()',
        #'add_ddc()',
        #'volume_sort()',
        'clean_department()',
    ]
);

my $file_fixer = Catmandu::Fix->new(
    fixes => [
        'move_field("file.fileOId", "file.file_id")',
        'copy_field("file.dateLastUploaded", "file.date_created")',
        'move_field("file.dateLastUploaded", "file.date_updated")',
        'move_field("file.isUploadedBy.login", "file.creator")',
        'remove_field("file.isOfType")',
        'remove_field("file.isUploadedBy")',
    ]
);

# checksum, fileSize

my $author_fixer = Catmandu::Fix->new(
    fixes => [
        'move_array_field("author.*.surname", "author.*.last_name")',
        'move_array_field("author.*.givenName", "author.*.first_name")',
        'move_array_field("author.*.personNumber", "author.*.id")',
        'move_array_field("author.*.fullName", "author.*.full_name")',
        'remove_array_field("author.*.email")',
        'remove_array_field("author.*.type")',
        'remove_array_field("author.*.oId")',
        'remove_array_field("author.*.departmentAffiliations")',
        'remove_array_field("author.*.luLdapId")',
        'remove_array_field("author.*.jobTitle")',
        'remove_array_field("author.*.personTitle")',
        'remove_array_field("author.*.searchName")',
        'remove_array_field("author.*.citationStyle")',
        'remove_array_field("author.*.sortDirection")',
    ]
);

my $editor_fixer = Catmandu::Fix->new(
    fixes => [
        'move_array_field("editor.*.surname", "editor.*.last_name")',
        'move_array_field("editor.*.givenName", "editor.*.first_name")',
        'move_array_field("editor.*.personNumber", "editor.*.id")',
        'move_array_field("editor.*.fullName", "editor.*.full_name")',
        'remove_array_field("editor.*.email")',
        'remove_array_field("editor.*.type")',
        'remove_array_field("editor.*.oId")',
        'remove_array_field("editor.*.departmentAffiliations")',
        'remove_array_field("editor.*.luLdapId")',
        'remove_array_field("editor.*.jobTitle")',
        'remove_array_field("editor.*.personTitle")',
    ]
);

my $supervisor_fixer = Catmandu::Fix->new(
    fixes => [
        'move_array_field("supervisor.*.surname", "supervisor.*.last_name")',
        'move_array_field("supervisor.*.givenName", "supervisor.*.first_name")',
        'move_array_field("supervisor.*.personNumber", "supervisor.*.id")',
        'move_array_field("supervisor.*.fullName", "supervisor.*.full_name")',
        'remove_array_field("supervisor.*.email")',
        'remove_array_field("supervisor.*.type")',
        'remove_array_field("supervisor.*.oId")',
        'remove_array_field("supervisor.*.departmentAffiliations")',
        'remove_array_field("supervisor.*.luLdapId")',
        'remove_array_field("supervisor.*.jobTitle")',
        'remove_array_field("supervisor.*.personTitle")',
    ]
);

my $supp_fixer = Catmandu::Fix->new(
    fixes => [
        'clean_suppmat()',
    ]
);

my $post_fixer = Catmandu::Fix->new(
    fixes => [
        #'remove_field("isOfType")',
        'remove_field("usesLanguage")',
        'remove_field("citations._id")',
        'remove_field("message")',
        'remove_field("isAReviewOf")',
        'remove_field("isHiddenFor")',
        'remove_field("isHiddenForAccount")',
        'remove_field("dateToTeacher")',
        #'hiddenFor_info()',
        #'schema_dot_org()',
    ]
);

#my $separate_fixer = Catmandu::Fix->new(
#    fixes => [ 'remove_field("additionalInformation")', ] );

my $bag    = Catmandu->store('search')->bag('publicationItem');
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
    $file_fixer->fix($rec);
    $author_fixer->fix($rec);
    $editor_fixer->fix($rec);
    $supervisor_fixer->fix($rec);
    $supp_fixer->fix($rec);
    
    #$rec->{citation} = $citbag->get( $rec->{_id} ) if $rec->{_id};
    $post_fixer->fix($rec);
    
    foreach my $key (keys %$rec){
    	my $ref = ref $rec->{$key};
    	
    	if($ref eq "ARRAY"){
    		if(!$rec->{$key}->[0]){
    			delete $rec->{$key};
    		}
    	}
    	elsif($ref eq "HASH"){
    		if(!%{$rec->{$key}}){
    			delete $rec->{$key};
    		}
    	}
    	else{
    		if($rec->{$key} and $rec->{$key} eq ""){
    			delete $rec->{$key};
    		}
    	}
    }

    ( $rec->{project} ) && ( $rec->{proj} = 1 );

    print Dumper $rec;

    #exit;

    #$bag->add($rec);
}

# get all publication types
my $types = $luur->getChildrenTypes( type => 'publicationItem' );

# foreach type get records
foreach (@$types) {
	
	#my $results = $db->find("id=2659314");
	#while ( my $rec = $results->next ) {
	
    my $obj = $luur->getObjectsByType( type => $_ );
    foreach (@$obj) {
        my $rec = $db->get($_);
        if (    $rec->{isOfType}->{typeName} ne "unknown"
            and $rec->{isOfType}->{typeName} ne "studentPaper"
            and $rec->{submissionStatus}
            and $rec->{submissionStatus} ne "pdeleted" )
        {
            add_to_index($rec);
            #print Dumper $rec;
            #exit;
        }
    }
    #print Dumper $rec;
    #exit;
    #add_to_index($rec);
	#}
}

#$bag->commit;

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
