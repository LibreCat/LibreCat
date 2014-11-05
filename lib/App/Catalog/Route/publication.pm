package App::Catalog::Route::publication;

=head1 NAME App::Catalog::Route::publication

    Route handler for publications.

=cut

use App::Catalog::Helper;
use App::Catalog::Controller::Publication;
use Dancer ':syntax';
use Dancer::FileUtils qw/path/;
use File::Copy;
use Try::Tiny;

=head1 PREFIX /record

    All actions related to a publication record are handled under
    this prefix.

=cut

prefix '/record' => sub {

=head2 GET /new

    Prints a list of available publication types + import form.
    Some fields are pre-filled.

=cut

    get '/new' => sub {
        my $type = params->{type};

        return template 'add_new' unless $type;

        my $data;
        my $id = new_publication();
        $data->{_id} = $id;
        my $user = h->getPerson( session->{personNumber} );
        $data->{department} = $user->{department};

        if ( $type eq "researchData" ) {
            $data->{doi} = h->config->{doi}->{prefix} . "/" . $id;
        }

        template "backend/forms/$type", $data;
    };

=head2 GET /edit/:id

    Display record for id.
    Checks if the user has permission the see/edit this record.

=cut

    get '/edit/:id' => sub {
        my $id = param 'id';

        forward '/' unless $id;
        my $rec;
        try {
            $rec = edit_publication($id);
        }
        catch {
            template 'error', { error => "Something went wrong: $_" };
        };

        if ($rec) {
            template "backend/forms/$rec->{type}", $rec;
        }
        else {
            template 'error', { error => "No publication with ID $id." };
        }
    };

=head2 POST /update

    Saves the record in the database.
    Checks if the user has the rights to update this record.
    Validation of the record is performed.

=cut

    post '/update' => sub {
        my $params = params;

        foreach my $key ( keys %$params ) {
            if ( ref $params->{$key} eq "ARRAY" ) {
                my $i = 0;
                foreach my $entry ( @{ $params->{$key} } ) {
                    $params->{ $key . "." . $i } = $entry, $i++;
                }
                delete $params->{$key};
            }
        }

        $params = h->nested_params($params);

        if ( ( $params->{department} and $params->{department} eq "" )
            or !$params->{department} )
        {
            $params->{department} = ();
            if ( session->{role} ne "super_admin" ) {
                my $person = h->getPerson( session->{personNumber} );
                foreach my $dep ( @{ $person->{department} } ) {
                    push @{ $params->{department} }, $dep->{id};
                }
            }
        }
        elsif ( $params->{department}
            and $params->{department} ne ""
            and ref $params->{department} ne "ARRAY" )
        {
            $params->{department} = [ $params->{department} ];
        }

        ( session->{role} eq "super_admin" )
            ? ( $params->{approved} = 1 )
            : ( $params->{approved} = 0 );

        $params->{creator} = session 'user' unless $params->{creator};

        my $result = update_publication($params);

        redirect '/myPUB';
    };

=head2 GET /return/:id

    Set status to 'returned'.
    Checks if the user has the rights to return this record.

=cut

    get '/return/:id' => sub {
        my $id  = params->{id};
        my $rec = h->publication->get($id);
        $rec->{status} = "returned";
        try {
            update_publication($rec);
        }
        catch {
            template "error", { error => "something went wrong" };
        };

        redirect '/myPUB';
    };

=head2 GET /delete/:id

    Deletes record with id. For admins only.

=cut

    get '/delete/:id' => sub {
        delete_publication( params->{id} );
        redirect '/myPUB';
    };

=head2 GET /preview/id

    Prints the frontdoor for every record.

=cut

    get '/preview/:id' => sub {
        my $id   = params->{id};
        my $hits = h->publication->get($id);
        $hits->{bag}
            = $hits->{type} eq "researchData" ? "data" : "publication";
        $hits->{style}
            = h->config->{store}->{default_fd_style} || "frontShort";
        $hits->{marked}  = 0;
        template 'frontend/frontdoor/record.tt', $hits;
    };

    get '/publish/:id' => sub {
        my $id     = params->{id};
        my $record = h->publication->get($id);

        #check if all mandatory fields are filled
        my $publtype = lc $record->{type};
        my $basic_fields
            = h->config->{forms}->{publicationTypes}->{$publtype}->{fields}
            ->{basic_fields};
        my $field_check = 1;

        foreach my $key ( keys %$basic_fields ) {
            next if $key eq "tab_name";
            if (    $basic_fields->{$key}->{mandatory}
                and $basic_fields->{$key}->{mandatory} eq "1"
                and ( !$record->{$key} || $record->{$key} eq "" ) )
            {
                $field_check = 0;
            }
        }

        $record->{status} = "public" if $field_check;
        my $result  = h->publication->add($record);
        my $publbag = Catmandu->store->bag('publication');
        $publbag->add($result);
        h->publication->commit;

        redirect '/myPUB';
    };
};

get '/upload' => sub {
    template "backend/upload.tt";
};

post '/upload' => sub {
    my $file    = request->upload('file');
    my $id = params->{_id};
    
    my $file_id = new_publication();
    my $path    = path( h->config->{upload_dir}, "$id", $file->{filename} );
    my $dir     = h->config->{upload_dir} . "/" . $id;
    mkdir $dir unless -e $dir;
    my $success = $file->copy_to($path);

    my $return;
    if ($success) {
        $return->{success}      = 1;
        $return->{file_name}    = $file->{filename};
        $return->{creator}      = session->{user};
        $return->{file_size}    = $file->{size};
        $return->{file_id}      = $file_id;
        $return->{date_updated} = "2014-07-20T12:00";                   #???
        $return->{access_level} = "openAccess";
        $return->{content_type} = $file->{headers}->{"Content-Type"};
        $return->{relation}     = "main_file";

        #$return->{error} = "this is not an error. Y U no display file?";
        $return->{file_json}
            = '{"file_name": "' . $return->{file_name} . '", ';
        $return->{file_json} .= '"file_id": "' . $return->{file_id} . '", ';
        $return->{file_json}
            .= '"content_type": "' . $return->{content_type} . '", ';
        $return->{file_json}
            .= '"access_level": "' . $return->{access_level} . '", ';
        $return->{file_json}
            .= '"date_updated": "' . $return->{date_updated} . '", ';
        $return->{file_json}
            .= '"date_created": "' . $return->{date_updated} . '", ';
        $return->{file_json} .= '"checksum": "ToDo", "file_size": "'
            . $return->{file_size} . '", ';
        $return->{file_json} .= '"relation": "main_file", ';
        $return->{file_json}
            .= '"language": "eng", "creator": "'
            . $return->{creator}
            . '", "open_access": "1", "year_last_uploaded": "2014"}';
    }
    else {
        $return->{success} = 0;
        $return->{error}   = "There was an error while uploading your file.";
    }

    return to_json($return);
};

post '/upload/qai' => sub {
    my $file    = request->upload('file');
    
    my $return;
    $return->{tempname} = $file->{tempname};
    $return->{filename} = $file->{filename};
    copy($file->{tempname}, h->config->{upload_dir}."/".$file->{filename});
    return to_json($return);
};

get '/upload/qai' => sub {
	my $tmp_file = params->{tmp_file};
	my $submit_or_cancel = params->{submit_or_cancel} || "Cancel";
	my $return;
	
	if($submit_or_cancel eq "Submit"){
		my $id = new_publication();
		my $file_id = new_publication();
		my $file_name = params->{file_name};
		$return->{saved} = 1;
		my $record;
		$record->{_id} = $id;
		$record->{title} = "New Quick And Easy Publication - Please edit";
		$record->{type} = "journalArticle";
		$record->{"author.0.first_name"} = "Petra";
		$record->{"author.0.last_name"} = "Kohorst";
		$record->{"author.0.full_name"} = "Kohorst, Petra";
		$record->{"author.0.id"} = "29676584";
		$record->{file} = ();
		push @{$record->{file}}, "{\"file_name\":\"".$file_name."\", \"file_id\":\"".$file_id."\", \"access_level\":\"openAccess\",\"date_updated\":\"2014-04-23T12:00:00\",\"date_created\":\"2014-04-23T12:00:00\",\"creator\":\"". session->{user} ."\",\"open_access\":\"1\",\"relation\":\"main_file\"}";
		$record->{year} = "2014";
		
		my $path = h->config->{upload_dir} . "/" . $id . "/" . $file_name;#path( h->config->{upload_dir}, "$id", $file_name );
        my $dir = h->config->{upload_dir} . "/" . $id;
        mkdir $dir unless -e $dir;
        move(h->config->{upload_dir}."/".$file_name,$path) or return to_dumper $! . " " . h->config->{upload_dir}. "/". $file_name . " " . $path;
        
        $record = h->nested_params($record);
        my $response = update_publication($record);
        
        $return->{response} = $response;
	}
	else{
		my $status = unlink $tmp_file;
		$return->{deleted} = 1;
	}
	
	my $return_json = to_json($return);
	my $params = params;
    return to_dumper $params;
};

post '/upload/update' => sub {
    my $file          = request->upload('file');
    my $old_file_name = params->{old_file_name};
    my $id            = params->{id};
    my $file_id       = params->{file_id};
    my $success       = 1;

    if ($file) {

        # first delete old file from dir
        my $deldir = h->config->{upload_dir} . "/$id/$old_file_name";
        my $status = unlink "$deldir" if -e $deldir;

        # then copy new file to dir
        my $path = path( h->config->{upload_dir}, "$id", $file->{filename} );
        my $dir = h->config->{upload_dir} . "/" . $id;
        mkdir $dir unless -e $dir;
        $success = $file->copy_to($path);
    }

    # then return data of updated file
    my $return;
    if ($success) {
        $return->{success}   = 1;
        $return->{file_name} = $file ? $file->{filename} : $old_file_name;
        $return->{creator}   = session->{user};
        $return->{file_size} = $file ? $file->{size} : "";
        $return->{file_id}   = $file_id;
        $return->{date_updated} = "2014-07-01T12:00";    #???
        $return->{access_level}
            = params->{access_level} ? params->{access_level} : "openAccess";
        $return->{open_access} = ( params->{access_level}
                and params->{access_level} eq "openAccess" ) ? 1 : 0;
        $return->{embargo} = params->{embargo} ? params->{embargo} : "";
        $return->{content_type}
            = $file ? $file->{headers}->{"Content-Type"} : "";
        $return->{checksum}    = "ToDo";
        $return->{file_title}  = params->{file_title} if params->{file_title};
        $return->{description} = params->{description}
            if params->{description};

        #$return->{error} = "this is not an error. Y U no display file?";
        $return->{old_file_name} = $old_file_name;
        $return->{relation}
            = params->{relation} ? params->{relation} : "main_file";

        my $record = h->publication->get($id);
        foreach my $recfile ( @{ $record->{file} } ) {
            if ( $recfile->{file_id} eq $return->{file_id} ) {
                $return->{year_last_uploaded}
                    = $recfile->{year_last_uploaded};
                $return->{file_size} = $recfile->{file_size}
                    if $return->{file_size} eq "";
                $return->{content_type}
                    = (     $return->{content_type} eq ""
                        and $recfile->{content_type} )
                    ? $recfile->{content_type}
                    : "";
                $return->{date_created} = $recfile->{date_created};
                if ( $return->{access_level} eq "openAccess" ) {
                    $return->{open_access} = 1;
                    $return->{embargo}     = "";
                }
                else {
                    $return->{open_access} = 0;
                }

                $recfile = ();
                $recfile = $return;
                delete $recfile->{file_json};
                delete $recfile->{success};
                delete $recfile->{old_file_name};
            }
        }

        $return->{file_json}
            = '{"file_name": "' . $return->{file_name} . '", ';
        $return->{file_json} .= '"file_id": "' . $return->{file_id} . '", ';
        $return->{file_json} .= '"title": "' . $return->{file_title} . '", '
            if $return->{file_title};
        $return->{file_json}
            .= '"description": "' . $return->{description} . '", '
            if $return->{description};
        $return->{file_json}
            .= '"content_type": "' . $return->{content_type} . '", ';
        $return->{file_json}
            .= '"access_level": "' . $return->{access_level} . '", ';
        $return->{file_json} .= '"embargo": "' . $return->{embargo} . '", '
            if ( $return->{embargo} and $return->{embargo} ne "" );
        $return->{file_json}
            .= '"date_updated": "' . $return->{date_updated} . '", ';
        $return->{file_json}
            .= '"date_created": "' . $return->{date_updated} . '", ';
        $return->{file_json} .= '"checksum": "ToDo", "file_size": "'
            . $return->{file_size} . '", ';
        $return->{file_json}
            .= '"language": "eng", "creator": "' . $return->{creator} . '", ';
        $return->{file_json}
            .= '"open_access": "' . $return->{open_access} . '", ';
        $return->{file_json} .= '"relation": "' . $return->{relation} . '", ';
        $return->{file_json} .= '"year_last_uploaded": "2014"}';

        h->publication->add($record);
        h->publication->commit;
    }
    else {
        $return->{success} = 0;
        $return->{error}   = "There was an error while uploading your file.";
    }

    #my $json = new JSON;
    my $return_json = to_json($return);
    return $return_json;
};

post '/upload/delete' => sub {
    my $recordid = params->{id};
    my $filename = params->{filename};
    my $dir      = h->config->{upload_dir} . "/$recordid/$filename";
    my $status   = rmdir $dir if -e $dir || 0;
    template 'error', { error => "Error: could not delete files" } if $status;
};

1;
