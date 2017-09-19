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
use LibreCat::App::Helper;
use LibreCat::App::Catalogue::Controller::Permission;
use DateTime;

sub _file_exists {
    my ($key, $filename, %opts) = @_;

    my $store = $opts{access} ? h->get_access_store() : h->get_file_store();

    return undef unless $store;

    my $container = $store->get($key);

    if (defined $container) {
        my $file = $container->get($filename);
        return $file;
    }
    else {
        return undef;
    }
}

sub _send_it {
    my ($key, $filename, %opts) = @_;

    my $store = $opts{access} ? h->get_access_store() : h->get_file_store();
    my $container = $store->get($key);

    send_file(
        \"dummy",    # anything, as long as it's a scalar-ref
        streaming => 1,    # enable streaming
        callbacks => {
            override => sub {
                my ($respond, $response) = @_;
                my $file         = $container->get($filename);
                my $content_type = $file->content_type;

                my $http_status_code = 200;

              # Tech.note: This is a hash of HTTP header/values, but the
              #            function below requires an even-numbered array-ref.
                my @http_headers = (
                    'Content-Type' => $content_type,
                    'Cache-Control' =>
                        'no-store, no-cache, must-revalidate, max-age=0',
                    'Pragma' => 'no-cache'
                );

         # Send the HTTP headers
         # (back to either the user or the upstream HTTP web-server front-end)
                my $writer = $respond->([$http_status_code, \@http_headers]);

                # Avoid creating forks whenever possible...
                if ($file->is_callback) {
                    $file->data->($writer);
                    $writer->close();
                }
                else {
                    my $io = $file->fh;
                    my $buffer_size
                        = h->config->{filestore}->{api}->{buffer_size}
                        // 1024;

                    while (!$io->eof) {
                        my $buffer;
                        $io->read($buffer, $buffer_size);
                        $writer->write($buffer);
                    }

                    $writer->close();
                    $io->close();
                }
            },
        },
    );
}

sub _calc_date {
    my $dt = DateTime->now();
    my $date_expires
        = $dt->add(days => h->config->{request_copy}->{period})->ymd;
    return $date_expires;
}

sub _get_file_info {
    my ($pub_id, $file_id) = @_;
    my $rec = Catmandu->store('main')->bag('publication')->get($pub_id);
    if ($rec->{file} and ref $rec->{file} eq "ARRAY") {
        my $matching_items
            = (grep {$_->{file_id} eq $file_id} @{$rec->{file}})[0];
        return $matching_items;
    }
}

=head2 GET /rc/approve/:key

Author approves the request. Email will be sent to user.

=cut

get '/rc/approve/:key' => sub {
    my $bag  = Catmandu->store('main')->bag('reqcopy');
    my $data = $bag->get(params->{key});
    return "Nothing to approve." unless $data;

    $data->{approved} = 1;
    $bag->add($data);

    my $body
        = export_to_string({key => params->{key}, uri_base => h->uri_base()},
        'Template', template => 'views/email/req_copy_approve.tt');

    my $job = {
        to      => $data->{user_email},
        subject => h->config->{request_copy}->{subject},
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
    my $bag  = Catmandu->store('main')->bag('reqcopy');
    my $data = $bag->get(params->{key});
    return "Nothing to deny." unless $data;

    my $job = {
        to      => $data->{user_email},
        subject => h->config->{request_copy}->{subject},
        body    => export_to_string(
            {}, 'Template', template => 'views/email/req_copy_deny.tt'
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
    my $check = Catmandu->store('main')->bag('reqcopy')->get(params->{key});
    if ($check and $check->{approved} == 1) {
        if (my $file = _file_exists($check->{record_id}, $check->{file_name}))
        {
            _send_it($check->{record_id}, $file->key);
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

=head2 POST /rc/:id/:file_id

Request a copy of the publication. Email will be sent to the author.

=cut

any '/rc/:id/:file_id' => sub {
    my $bag = Catmandu->store('main')->bag('reqcopy');
    my $file = _get_file_info(params->{id}, params->{file_id});
    unless ($file->{request_a_copy}) {
        forward '/publication/' . params->{id}, {method => 'GET'};
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

    my $file_creator_email = h->get_person($file->{creator})->{email};
    if (params->{user_email}) {
        my $pub
            = Catmandu->store('main')->bag('publication')->get(params->{id});
        my $mail_body = export_to_string(
            {
                title      => $pub->{title},
                user_email => params->{user_email},
                mesg       => params->{mesg} || '',
                key        => $stored->{_id},
                uri_base   => h->uri_base(),
            },
            'Template',
            template => 'views/email/req_copy.tt',
        );
        my $job = {
            to      => $file_creator_email,
            subject => h->config->{request_copy}->{subject},
            body    => $mail_body,
        };

        try {
            h->queue->add_job('mailer', $job);
            return redirect uri_for("/publication/" . params->{id});
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

=head2 GET /download/:id/:file_id

Download a document. Access level of the document
and user rights will be checked before.

=cut

get qr{/download/([0-9A-F-]+)/([0-9A-F-]+).*} => sub {
    my ($id, $file_id) = splat;

    my ($ok, $file_name)
        = p->can_download($id, $file_id, session->{user}, session->{role},
        request->address);

    unless ($ok) {
        status 403;
        return template '403';
    }

    if (my $file = _file_exists($id, $file_name)) {
        _send_it($id, $file->key);
    }
    else {
        status 404;
        template 'error',
            {message => "The file does not exist anymore. We're sorry."};
    }
};

=head2 GET /thumbnail/:id

Download the thumbnail of the document

=cut

get '/thumbnail/:id' => sub {
    my $key            = params->{id};
    my $thumbnail_name = 'thumbnail.png';

    if (my $file = _file_exists($key, $thumbnail_name, access => 1)) {
        _send_it($key, $file->key, access => 1);
    }
    else {
        redirect uri_for('/images/thumbnail_dummy.png');
    }
};

1;
