package LibreCat::App::Catalogue::Route::file;

=head1 NAME

LibreCat::App::Catalogue::Route::file - routes for file handling:
upload & download files, request-a-copy.
All these must be public.

=cut

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Dancer ':syntax';
use Dancer::Plugin::Auth::Tiny;
use Dancer::Plugin::StreamData;
use LibreCat qw(:self publication);
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::Permission;
use DateTime;
use Catmandu::Util qw(:is);
use URI::Escape qw(uri_escape uri_escape_utf8);

#str_format( "%f.%e", f => "DS.0", e => "txt" )
sub str_format {
    my ($str, %args) = @_;
    for (keys %args) {
        my $val = $args{$_};
        $str =~ s/\%$_/$val/g;
    }
    $str;
}

sub _file_exists {
    my ($key, $filename, %opts) = @_;

    my $store = $opts{access} ? h->get_access_store() : h->get_file_store();

    return undef unless $store;

    if ($store->index->exists($key)) {
        return $store->index->files($key)->get($filename);
    }
    else {
        return undef;
    }
}

sub _send_it {
    my ($key, $file, %opts) = @_;

    return undef unless $key && $file;

    # Find the file identifier as recorded in the metadata record (the
    # $file is a record from the FileStore where the _id field contains
    # the original file name).
    my $record       = publication->get($key);
    my $record_files = $record->{file} // [];
    my $file_id      = 0;

    for (@$record_files) {
        if ($_->{file_name} eq $file->{_id}) {
            $file_id = $_->{file_id};
            last;
        }
    }

    my $format = h->config->{filestore}->{download_file_name};
    $format = is_string($format) ? $format : "%o";

    my $extension = h->file_extension($file->{_id});
    $extension =~ s/^\.//o;

    my $name = str_format(
        $format,
        i => $key,
        o => $file->{_id},
        f => $file_id,
        e => $extension
    );

    #builtin download headers
    my %http_headers = (
        'Content-Type'          => '%s',
        'Cache-Control'         => 'no-store, no-cache, must-revalidate, max-age=0',
        'Pragma'                => 'no-cache',
        'Content-Disposition'   => "inline; filename*=UTF-8''%s"
    );

    # Override builtin download headers ..
    my $o_download_headers      = h->config->{filestore}->{download_headers};
    $o_download_headers         = is_hash_ref( $o_download_headers ) ? $o_download_headers : +{};

    # .. for all
    my $o_download_headers_all  = is_hash_ref( $o_download_headers->{for_all} ) ? $o_download_headers->{for_all} : +{};

    # .. by content type
    my $o_download_headers_ct   = is_hash_ref( $o_download_headers->{for_content_type} ) && is_hash_ref( $o_download_headers->{for_content_type}->{ $file->{content_type} }  ) ?
        $o_download_headers->{for_content_type}->{ $file->{content_type} } : +{};

    %http_headers = ( %http_headers, %$o_download_headers_all, %$o_download_headers_ct );

    $http_headers{'Content-Type'} = sprintf( $http_headers{'Content-Type'}, $file->{content_type} );
    $http_headers{'Content-Disposition'} = sprintf( $http_headers{'Content-Disposition'}, URI::Escape::uri_escape_utf8($name) );
    $http_headers{'Content-Length'} = $file->{size};

    send_file(
        \"dummy",    # anything, as long as it's a scalar-ref
        streaming => 1,    # enable streaming
        callbacks => {
            override => sub {
                my ($respond, $response) = @_;
                my $http_status_code = 200;

              # Tech.note: This is a hash of HTTP header/values, but the
              #            function below requires an even-numbered array-ref.

         # Send the HTTP headers
         # (back to either the user or the upstream HTTP web-server front-end)
                my $writer = $respond->([$http_status_code, [ %http_headers ]]);

                $file->{_stream}->(h->io_from_plack_writer($writer), $file);
            },
        },
    );
}

sub _calc_date {
    my $dt = DateTime->now();
    my $date_expires
        = $dt->add(days => h->config->{request_copy}->{period})->ymd
        || h->log->error(
        "Could not calculate date. Need config option request_copy.period.");
    return $date_expires;
}

sub _get_file_info {
    my ($pub_id, $file_id) = @_;
    my $rec = h->main_publication->get($pub_id);
    if ($rec->{file} and ref $rec->{file} eq "ARRAY") {
        my $matching_items
            = (grep {$_->{file_id} eq $file_id} @{$rec->{file}})[0];
        return $matching_items;
    }
}

sub _handle_download {

    my( %args ) = @_;

    my $id = delete $args{id};
    my $file_id = $args{file_id};

    my ($ok, $file_name) = p->can_download(
        $id,
        {
            file_id => $file_id,
            user_id => session->{user_id},
            role    => session->{role},
            ip      => request->address
        }
    );

    unless ($ok) {
        status 403;
        return template '403';
    }

    if (my $file = _file_exists($id, $file_name)) {
        _send_it($id, $file);
    }
    else {
        status 404;
        template 'error',
            {message => "The file does not exist anymore. We're sorry."};
    }
}

sub _get_template_include_path {
    state $paths = join (':', map {"$_/email"} @{librecat->template_paths});
}

=head2 GET /rc/approve/:key

Author approves the request. Email will be sent to user.

=cut

get '/rc/approve/:key' => sub {
    my $bag  = h->main_reqcopy;
    my $data = $bag->get(params->{key});
    return "Nothing to approve." unless $data;

    $data->{approved} = 1;
    $bag->add($data);

    my $body = export_to_string(
        {
            key           => params->{key},
            uri_base      => h->uri_base(),
            appname_short => h->loc("appname_short")
        },
        'Template',
        INCLUDE_PATH => _get_template_include_path,
        ABSOLUTE => 1,
        template     => 'req_copy_approve.tt'
    );

    my $job = {
        to      => $data->{user_email},
        subject => h->config->{request_copy}->{subject},
        from    => h->config->{request_copy}->{from},
        body    => $body,
    };

    try {
        h->queue->add_job('mailer', $job);
        return
            "Thank you for your approval. The user will be notified to download the file.";
    }
    catch {
        h->log->error("Could not send email: $_");
    }
};

=head2 GET /rc/deny/:key

Author refuses the request for a copy. Email will be sent
to user. Delete request key from database.

=cut

get '/rc/deny/:key' => sub {
    my $bag  = h->main_reqcopy;
    my $data = $bag->get(params->{key});
    return "Nothing to deny." unless $data;

    my $job = {
        to      => $data->{user_email},
        subject => h->config->{request_copy}->{subject},
        from    => h->config->{request_copy}->{from},
        body    => export_to_string(
            {appname_short => h->loc("appname_short")}, 'Template',
            INCLUDE_PATH => _get_template_include_path,
            ABSOLUTE => 1,
            template     => 'req_copy_deny.tt'
        ),
    };

    try {
        h->queue->add_job('mailer', $job);
        $bag->delete(params->{key});
        return "The user will be notified that the request has been denied.";
    }
    catch {
        h->log->error("Could not send email: $_");
    }
};

=head2 GET /rc/:key

User received permission for downloading.
Now get the document if time has not expired yet.

=cut

get '/rc/:key' => sub {
    my $check = h->main_reqcopy->get(params->{key});
    if ($check and $check->{approved} == 1) {
        if (my $file = _file_exists($check->{record_id}, $check->{file_name}))
        {
            _send_it($check->{record_id}, $file);
        }
        else {
            status 404;
            template 'websites/error',
                {message => "The file does not exist anymore. We're sorry."};
        }
    }
    else {
        template 'websites/error',
            {message =>
                "The time slot has expired. You can't download the document anymore."
            };
    }
};

=head2 ANY /rc/:id/:file_id

Request a copy of the publication. Email will be sent to the author.

=cut

any '/rc/:id/:file_id' => sub {
    my $bag = h->main_reqcopy;
    my $file = _get_file_info(params->{id}, params->{file_id});
    unless ($file->{request_a_copy}) {
        forward '/record/' . params->{id}, {method => 'GET'};
    }

    my $date_expires = _calc_date();

    my $stored = $bag->add(
        {
            record_id    => params->{id},
            file_id      => params->{file_id},
            file_name    => $file->{file_name},
            date_expires => $date_expires,
            user_email   => params->{user_email},
            approved     => params->{approved} || 0,
        }
    );

    my $email = h->get_person($file->{creator})->{email};

    if (params->{user_email}) {
        my $pub
            = Catmandu->store('main')->bag('publication')->get(params->{id});

        # override creator email if email field is set for request-a-copy
        if ($pub->{file}) {
            my $file_metadata
                = (grep {$_->{file_id} eq params->{file_id}} @{$pub->{file}})
                [0];
            $email = $file_metadata->{rac_email}
                if $file_metadata->{rac_email};
        }

        my $mail_body = export_to_string(
            {
                record_id     => $stored->{record_id},
                title         => $pub->{title},
                user_email    => params->{user_email},
                mesg          => params->{mesg} || '',
                key           => $stored->{_id},
                uri_base      => h->uri_base(),
                appname_short => h->loc("appname_short"),
            },
            'Template',
            INCLUDE_PATH => _get_template_include_path,
            ABSOLUTE => 1,
            template     => 'req_copy.tt',
        );

        my $job = {
            to      => $email,
            subject => h->config->{request_copy}->{subject},
            from    => h->config->{request_copy}->{from},
            body    => $mail_body,
        };

        try {
            h->queue->add_job('mailer', $job);
            return redirect uri_for("/record/" . params->{id});
        }
        catch {
            h->log->error("Could not send email: $_");
        }
    }
    else {
        my $url = uri_for("/rc/" . $stored->{_id});
        content_type "application/json";
        return Dancer::to_json {
            ok  => 1,
            url => "$url",    # need to quotes here!
        };
    }
};

=head2 GET /download/:id/:file.:extension

Same as route below, but with extension

=cut

get "/download/:id/:file_id.:extension" => sub {
    my $r_params = params("route");
    _handle_download( id => $r_params->{id}, file_id => $r_params->{file_id} );
};

=head2 GET /download/:id/:file_id/:file_name

Same as route below, but with file_name included to help search results

=cut

get "/download/:id/:file_id/:file_name" => sub {
    my $r_params = params("route");
    _handle_download( id => $r_params->{id}, file_id => $r_params->{file_id} );
};

=head2 GET /download/:id/:file_id

Download a document. Access level of the document
and user rights will be checked before.

=cut

get "/download/:id/:file_id" => sub {
    my $r_params = params("route");
    _handle_download( id => $r_params->{id}, file_id => $r_params->{file_id} );
};

=head2 GET /thumbnail/:id

Download the thumbnail of the document

=cut

get '/thumbnail/:id' => sub {
    my $key            = params->{id};
    my $thumbnail_name = 'thumbnail.png';

    if (my $file = _file_exists($key, $thumbnail_name, access => 1)) {
        _send_it($key, $file, access => 1);
    }
    else {
        redirect uri_for('/images/thumbnail_dummy.png');
    }
};

1;
