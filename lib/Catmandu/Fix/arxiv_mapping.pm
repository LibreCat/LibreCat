package Catmandu::Fix::arxiv_mapping;

use Catmandu::Sane;
use Catmandu::Fix::add_field as => 'add_field';
use Catmandu::Fix::move_field as => 'move_field';
use Catmandu::Fix::append as => 'append';

use Moo;

sub fix {
	my ($self, $pub) = @_;

    foreach my $au ( @{$pub->{author}} ) {
        my $lastName = $au->{'name'};
        $lastName =~ s/.*\s(\S+)$/$1/;
        my $firstName = $au->{'name'};
        $firstName =~ s/(.*)\s(\S+)$/$1/;
        my $fullname = $lastName.', '.$firstName;
        push @{$pub->{NEWauthors}}, $fullname;
    }

    move_field($pub,"summary","abstract.text");
    add_field($pub, "abstract.lang", "eng");
    move_field($pub,"arxiv:journal_ref.content","publication");
    move_field($pub,"arxiv:doi.content","doi");
    #append($pub,"category.term","message", -join => '; ');
    $pub->{message} = join ()
    return $pub;
}

1;

__END__
# old code from sbcat:
sub arxiv {
    # TODO: Make own package
    my $self = shift;
    my $loginAccount = $self->{loginAccount};
    my $luur         = $self->{luur};
    my $web          = $self->{web};
    my $cfg          = $self->cfg;
    use LWP::UserAgent;
    use XML::Simple;
    use utf8;
    my $tm = localtime;
    my $accountOId  = $loginAccount->{oId};
    my $searchQuery = '';
    my $idList      = '';

    if (defined($web->{arxivAuthorSubmit})) {
        unless ($web->{surname}) {
            $web->{surname}             = $loginAccount->{ownerSurname};
            $web->{givenname}           = $loginAccount->{ownerGivenName};
            $web->{errorMessagesArxiv}  = [ {message => "No Surname given."}];
            return $self->printTemplate( 'endNoteImport', $web);
        }
        $searchQuery   = 'au:' . $web->{surname};
        $searchQuery  .= '_' . substr($web->{givenname},0,1) if $web->{givenname};
    } else {
        $idList   = $web->{idlist};
#         my @ids = split /\s*,\s*/, $idList;
#         foreach my $id (@ids) {
#             unless ($id =~ m{\S*/\S*}) {
#                 $web->{errorMessagesArxiv}  = [ {message => "Given ID $id is in invalid format.<br />A valid arXiv.org ID has the form '[Category]/[Identifier]'.<br />E.g. 'astro-ph/9410086v1'."}];
#                 $web->{surname}             = $loginAccount->{ownerSurname};
#                 $web->{givenname}           = $loginAccount->{ownerGivenName};
#                 return $self->printTemplate( 'endNoteImport', $web);
#             }
#         }
    }

    # Fetch
    my $url         = 'http://export.arxiv.org/api/query?search_query='.$searchQuery.'&id_list='.$idList.'&start=0&max_results=2000';#au:Wachsmuth_S
    my $browser     = LWP::UserAgent->new();
    my $response    = $browser->get($url);
#     use Data::Dumper;print "Content-type: text/plain\n\n";
#         print Dumper ($response); 
#         exit();

    # Parse Response
    my $xmlParser   = new XML::Simple();
    my $xml         = $xmlParser->XMLin($response->content(), forcearray => ['entry' , 'author' , 'name' , 'category' , 'arxiv:affiliation']);#->content()

    my $entries     = $xml->{entry};
#     use Data::Dumper;print "Content-type: text/plain\n\n";
#         print Dumper ($entries); exit();

    while ((my $id, my $entry) = each(%{$entries})) {
        $id =~ s#(http://arxiv.org/abs/*)([^v]+)([v]*)(\d*)#$2#;
#     die $id;
        if ($entry->{title} eq 'Error') {
            $web->{errorMessagesArxiv}  = [ {message => "arXiv.org responded an error message:<br />".$entry->{summary}}];
            $web->{surname}             = $loginAccount->{ownerSurname};
            $web->{givenname}           = $loginAccount->{ownerGivenName};
            return $self->printTemplate( 'endNoteImport', $web);
        }
        my $record;
        $record = {};
        # quick fix. What for?
        $record->{separator} = ';';
        $record->{order} = 'lName';
        $record->{partSeparator} = ',';
        # Sth2do with authors editors and subjects (?)
        foreach ( qw(au ed su) ) {
            $record->{"${_}_order"} = $record->{order};
            $record->{"${_}_partSeparator"} = $record->{partSeparator};
        }
        $record->{arxivID} = $id;
        $record->{externalIdentifier} = 'arXiv:'.$id;
        $record->{type} = 'preprint';
        $record->{message} = 'via arXiv.org-Import at ' . $tm;
        $record->{submissionStatus} = 'unsubmitted';

    #     $record->{departments} # Kann nach Einbindung durch Autor-Dept gefuellt werden; ggf fuer alle Importe
    # Ebenso dort LuAuthor-Zuordnung nach String-Vergleich

        while ((my $fieldname, my $fieldcontent) = each(%{$entry})) {
            #utf8::decode($fieldcontent);
            $record->{mainTitle}                = $fieldcontent if $fieldname eq 'title';
            $record->{abstract}                 = $fieldcontent if $fieldname eq 'summary';
            $record->{publication}              = $fieldcontent->{content} if $fieldname eq 'arxiv:journal_ref';
            $record->{doi}                      = $fieldcontent->{content} if $fieldname eq 'arxiv:doi';
            $record->{additionalInformation}   .= "$fieldname = ".$fieldcontent->{term}."\n"    if $fieldname eq 'arxiv:primary_category';
            $record->{additionalInformation}   .= "$fieldname = ".$fieldcontent->{content}."\n" if $fieldname eq 'arxiv:comment';

            if ($fieldname eq 'published') {
                my $dateyear = $fieldcontent;
                $dateyear =~ s/(\d{4}).*/$1/;
                $record->{publishingYear} = $dateyear;
            }
# 'author' => [
#                                                             {
#                                                               'name' => [
#                                                                         'M. Cheng'
#                                                                       ]
#                                                             },
#                                                             {
#                                                               'name' => [
#                                                                         'N. H. Christ'
#                                                                       ]
#                                                             },
#                                                             {
#             if ($fieldname eq 'link') {
#                 foreach my $link (@$fieldcontent) {
#                     push @{$record->{url}}, $link->{href}   if $link->{title} eq 'pdf' && $link->{rel} eq 'related';
#                 }
#             }
# 'author' => {
#                                                             'P. Petreczky' => {},
#                                                             'O. Kaczmarek' => {},
#                                                             'C. Jung' => {},


            if ($fieldname eq 'author') {
                foreach my $author (@$fieldcontent) {
#                 while ((my $authorname, my $authorAdditional) = each(%{$fieldcontent})) {
                    my $authorname = $author->{'name'};
                    utf8::decode(@$authorname[0]);
                    my $lastName    = @$authorname[0];
                    $lastName =~ s/.*\s(\S+)$/$1/;
                    my $firstName    = @$authorname[0];
                    $firstName =~ s/(.*)\s(\S+)$/$1/;
#     use Data::Dumper;print "Content-type: text/plain\n\n";
# print Dumper ($firstName); exit();
                    my $fullname = $lastName.', '.$firstName;
                    push @{$record->{authors}}, $fullname;
#                     if ($authorAdditional->{'arxiv:affiliation'}) {
#                         my $affs = $authorAdditional->{'arxiv:affiliation'};
# #                         print Dumper $affs;exit();
#                         foreach my $aff (@$affs) {
#                             $record->{additionalInformation}   .= "Author $fullname affiliation = ".$aff->{'content'}."\n";
#                         }
#                     }
#                     $record->{additionalInformation}   .= "Author $fullname affiliation = ".$authorAdditional->{'arxiv:affiliation'}->{'content'}."\n" if $authorAdditional->{'arxiv:affiliation'};
                }
            }

            if ($fieldname eq 'category') {
                foreach my $category (@$fieldcontent) {
                    $record->{additionalInformation}   .= "category = ".$category->{term}."\n";
                }
            }
    # print Dumper $fieldcontent if $fieldname eq 'link';
          #  if ($fieldname eq 'link') {
          #      foreach my $link (@$fieldcontent) {
           #         push @{$record->{url}}, $link->{href}   if $link->{title} eq 'pdf' && $link->{rel} eq 'related';
           #     }
            #}
    # print Dumper $fieldcontent if $fieldname eq 'arxiv:doi';
        }
#         print Dumper $record;
#         print "\n\n======= NEXT ENTRY =======================================\n\n";
            my $result;
            $result->{recordId} = $self->addImportedRecord ($accountOId, $record);
            $result->{recordTitle} = $record->{mainTitle};

            push @{$web->{records}}, $result; 

    }# 
    $web->{messageField} = 'via arXiv.org-Import at ' . $tm;

    $self->printTemplate( 'importArxivStatus', $web);
}