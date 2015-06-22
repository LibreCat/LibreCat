#!/usr/local/bin/perl

use lib qw(/srv/www/sbcat/lib /srv/www/sbcat/lib/extension /srv/www/sbcat/lib/default /home/bup/perl5/lib/perl5);
use Catmandu::Sane;
use Catmandu -all;
use Catmandu::Fix qw(start_end_year_from_date);
use Getopt::Std;
use Data::Dumper;
use Catmandu::Exporter::JSON;
getopts('u:m:');
our $opt_u;

# m for multiple indices
our $opt_m;

my $index_name = "pub";
if ($opt_m) {
        if ($opt_m eq 'pub1' || $opt_m eq 'pub2') {
                $index_name = $opt_m;
        } else {
                die "$opt_m is not an valid option";
        }
}

Catmandu->load;
my $conf = Catmandu->config;


####
# interim sub for History projects
####
sub _do_stuff {
        my $rec = shift;
    
    if($rec->{member} and $rec->{member} =~ /,/){
        my @members = split(",",$rec->{member});
        foreach (@members){
                $_ =~ s/^\s+|\s+$//g;
                my ($title, $firstname, $lastname, $addition) = &_manageNames($_);
                push @{$rec->{projectMembers}}, {id => "", full_name => $lastname . ", " . $firstname, first_name => $firstname, last_name => $lastname, addition => $addition};
        }
    }
    elsif($rec->{member} and $rec->{member} ne ""){
        my ($title, $firstname, $lastname, $addition) = &_manageNames($rec->{member});
        push @{$rec->{projectMembers}}, {id => "", full_name => $lastname . ", " . $firstname, first_name => $firstname, last_name => $lastname, addition => $addition};
    }
    
    if($rec->{funder} and $rec->{funder} =~ /;/){
        my @funders = split(";",$rec->{funder});
        foreach (@funders){
                $_ =~ s/^\s+|\s+$//g;
                push @{$rec->{projectFunders}}, $_;
        }
    }
    elsif($rec->{funder} and $rec->{funder} ne ""){
        push @{$rec->{projectFunders}}, $rec->{funder};
    }
    
    if($rec->{cooperator} and $rec->{cooperator} =~ /,/){
        my @cooperators = split(",",$rec->{cooperator});
        foreach (@cooperators){
                $_ =~ s/^\s+|\s+$//g;
                push @{$rec->{projectCooperators}}, $_;
        }
    }
    elsif($rec->{cooperator} and $rec->{cooperator} ne ""){
        push @{$rec->{projectCooperators}}, $rec->{cooperator};
    }
    
    if($rec->{coordinator} and $rec->{coordinator} =~ /,/){
        my @coordinators = split(",",$rec->{coordinator});
        foreach (@coordinators){
                $_ =~ s/^\s+|\s+$//g;
                my ($title, $firstname, $lastname, $addition) = &_manageNames($_);
                push @{$rec->{owner}}, {id => "", full_name => $lastname . ", " . $firstname, first_name => $firstname, last_name => $lastname, addition => $addition};
        }
    }
    elsif($rec->{coordinator} and $rec->{coordinator} ne ""){
        my ($title, $firstname, $lastname, $addition) = &_manageNames($rec->{coordinator});
        push @{$rec->{owner}}, {id => "", full_name => $lastname . ", " . $firstname, first_name => $firstname, last_name => $lastname, addition => $addition};
    }
    
    my $dept_names = {"10023" => "Abteilung Geschichte",
        "3791069" => "Alte Geschichte",
        "3791073" => "Geschichte als Beruf",
        "3791087" => "Geschichte des Mittelalters und der Frühen Neuzeit",
        "3791078" => "Geschichte des 19. und 20. Jahrhunderts",
        "3791096" => "Geschlechtergeschichte",
        "37416959" => "Historische Wissenschaftsforschung",
        "32742431" => "Historische Bildwissenschaft-Kunstgeschichte",
        "3791099" => "Iberische und lateinamerikanische Geschichte",
        "3791103" => "Osteuropäische Geschichte",
        "3791091" => "Geschichte moderner Gesellschaften",
        "3791114" => "Wirtschaftsgeschichte",
        "35573039" => "Didaktik der Geschichte",
        "40284404" => "Region in der Geschichte",
        "3803979" => "Historische Politikforschung",
        "3652153" => "Schule für Historische Forschung",
        "3791107" => "Sozialgeschichte",
        "3791111" => "Technik- und Umweltgeschichte",
        "3791117" => "Zeitgeschichte",
        "16813171" => "ENTRY",
        "19409167" => "Kompetenznetz Lateinamerika",
        "34961736" => "Geschichte des Hoch- und Spätmittelalters",
    };
    
    if($rec->{department} and $rec->{department} =~ /|/){
        my @departments = split(/\|/, $rec->{department});
        foreach my $dept (@departments){
                push @{$rec->{isOwnedByDepartment}}, {id => $dept, name => $dept_names->{$dept}};
        }
    }
    elsif($rec->{department}){
        push @{$rec->{isOwnedByDepartment}}, {id => $rec->{department}, name => $dept_names->{$rec->{department}}};
    }
    return $rec;
}

sub _manageNames {
        my $projectOwner = "";
        $projectOwner = $_[0];
        if($projectOwner ne ""){
                $projectOwner =~ s/^Herr //g;
                $projectOwner =~ s/^Frau //g;
                $projectOwner =~ s/^\s+|\s+$//g;
                $projectOwner =~ s/PD/PD\./g;
                $projectOwner =~ s/zusammen mit //g;
                
                my $forename = ""; my $lastname = ""; my $title = ""; my $addition = "";
                if($projectOwner =~ /.*(\(.*?\))$/){
                	$addition = $1;
                	$projectOwner =~ s/\(.*?\)$//g;
                }
                if($projectOwner =~ /,/){
                        ($lastname, $forename) = split /,/, $projectOwner;
                        $forename =~ s/^\s+|\s+$//g;
                        $projectOwner = "";
                }
                
                if($projectOwner =~ /(.*nat\. |.*em\. |.*mult\. |.*h\.c\. |.*habil\. |.*i\.R\. |.*Ing\. |.*Biol\. |.*Psych\. |.*Ph.D\. |.*PhD |.*PD\. |.*phil\. |.*M\.A\. |.*Päd\. |.*Soz\. |.*Sozw\. |.*Chem\. |.*soc\. )(.*)/){
                        $title = $1;
                        $projectOwner = $2;
                }
                
                if($projectOwner =~ /(.*Prof\..* Dr\. |.*Prof\. |.*Dr\. |.*Professor )(.*)/){
                        if($title ne ""){
                                $title .= " ".$1;
                        }
                        else {
                                $title = $1;
                        }
                        $projectOwner = $2;
                }
                
                if($projectOwner =~ /(.*) (von .*|van .*|da .*|Graf v. .*)/){
                        $forename = $1;
                        $lastname = $2;
                        $projectOwner = "";
                }
                
                if($projectOwner =~ /(.*) (.*)/){
                        $forename = $1;
                        $lastname = $2;
                }
                
                return ($title, $forename, $lastname, $addition);
        } else {
                return ("", "", "", "");
        }
        
}


my $pre_fixer = Catmandu::Fix->new(fixes => [
                        'start_end_year_from_date()',
                ]);

#my $mongoBag = Catmandu->store('project')->bag;
#my $projBag = Catmandu->store('search', index_name => $index_name)->bag('project');
my $exporter = Catmandu::Exporter::JSON->new(file => "hist_project.json");
if ($opt_u) { # update process
#       my $project = $mongoBag->get($opt_u);
#       $pre_fixer->fix($project);
#       ($project) ? ($projBag->add($project)) : ($projBag->delete($opt_u));
        
} else { # initial indexing

#       my $allProj = $mongoBag->to_array;
#       foreach (@$allProj){
#               $pre_fixer->fix($_);
#               $projBag->add($_)
#       }
        
        
        #####
        # interim Loesung fuer Geschichtsprojekte
        #####
        use Catmandu;
        use Catmandu::Importer::CSV;
        use Catmandu::Fix;
        
        my $imp = Catmandu::Importer::CSV->new(file => "/srv/www/pub/bin/history.csv");
        my $hist_fixer = Catmandu::Fix->new(fixes => [
            'remove_field("member")',
            'move_field("projectMembers","member")',
            'remove_field("funder")',
            'move_field("projectFunders","funder")',
            'remove_field("cooperator")',
            'move_field("projectCooperators","cooperator")',
            'remove_field("department")',
            'move_field("isOwnedByDepartment","department")',
            'remove_field("coordinator")',
            'move_field("projecttype","project_type")',
        ]);
        
        $imp->each(sub {
                my $hashref = $_[0];
                $hashref = _do_stuff($hashref);
                $hist_fixer->fix($hashref);
                $pre_fixer->fix($hashref);
                $exporter->add($hashref);
        }); 

}


=head1 SYNOPSIS

Script for indexing project data

=head2 Initial indexing

perl index_project.pl

# fetches all data from project mongodb and pushes it into the search store

=head2 Update process

perl index_project.pl -u 'ID'

# fetches one record with the id 'ID' and pushes it into the search storej or deletes it if 'ID' not found anymore

=head1 VERSION

0.02, Oct. 2012

=cut
