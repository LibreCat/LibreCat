package App::Catalogue::Route::file;

=head1 NAME

App::Catalogue::Route::file - routes for file handling:
upload & download files, request-a-copy.
All these must be public.

=cut

use Catmandu::Sane;
use Catmandu qw(export_to_string);
use Dancer ':syntax';
use Dancer::Request;
use Dancer::Plugin::Email;
use Dancer::Plugin::Auth::Tiny;
use App::Helper;
use App::Catalogue::Controller::Permission qw/can_download/;
use DateTime;
use Try::Tiny;

sub _send_it {
	my ($id, $file_name) = @_;
	my $dest_dir = h->get_file_path($id);
	my $path_to_file = path($dest_dir, $file_name);
	return Dancer::send_file($path_to_file, system_path => 1);
}

sub _calc_date {
	my $dt = DateTime->now();
	my $date_expires = $dt->add(days => h->config->{request_copy}->{period})->ymd;
	return $date_expires;
}

sub _get_file_info {
	my ($pub_id, $file_id) = @_;
	my $rec = h->publication->get($pub_id);
	if($rec->{file} and ref $rec->{file} eq "ARRAY"){
		my $matching_items = (grep {$_->{file_id} eq $file_id} @{$rec->{file}})[0];
		return $matching_items;
	}
}

=head1 PREFIX /rc

Prefix for the feature 'request-a-copy'

=cut
prefix '/rc' => sub {

=head2 GET /rc/:id/:file_id

Request a copy of the publication. Email will be sent to the author.

=cut
	post '/:id/:file_id' => sub {
		my $bag = Catmandu->store->bag('request');
		my $file = _get_file_info(params->{id}, params->{file_id});
		unless ($file->{request_a_copy}) {
			forward '/publication/'.params->{id}, {method => 'GET'};
		}

		my $date_expires = _calc_date();

		my $query = {
			approved => 1,
			file_id => params->{file_id},
			file_name => $file->{file_name},
			date_expires => $date_expires,
			record_id => params->{id},
			};

		my $hits = $bag->search(
		    query => $query,
		    limit => 1
		);

		if ($hits->first){
			return to_json {
				ok => true,
				url => h->host . "/rc/" . $hits->first->{_id},
			};
		} else {
			my $stored = $bag->add({
				record_id => params->{id},
				file_id => params->{file_id},
				file_name => $file->{file_name},
				date_expires => $date_expires,
				user_email => params->{user_email},
				approved => params->{approved} || 0,
			});

			my $file_creator_email = h->get_person($file->{creator})->{bis}->{email};
			if(params->{user_email}){
				my $pub = h->publication->get(params->{id});
				my $mail_body = export_to_string({
					title => $pub->{title},
					user_email => params->{user_email},
					mesg => params->{mesg} || '',
					key => $stored->{_id},
					host => h->host,
					},
					'Template',
					template => 'views/email/req_copy.tt',
				);
				try {
					email {
						to => $file_creator_email,
						subject => h->config->{request_copy}->{subject},
						body => $mail_body,
					};
					#forward '/publication/'.params->{id}, {method => 'GET'};
				} catch {
					error "Could not send email: $_";
				}
			} else {
				return h->host . "/rc/" . $stored->{_id};
			}
		}
	};

=head2 GET /rc/approve/:key

Author approves the request. Email will be sent to user.

=cut
	get '/approve/:key' => sub {
		forward '/rc/approve', {key => params->{key}}, {method => 'POST'};
	};

	post '/approve' => sub {
		my $bag = Catmandu->store->bag('request');
		my $data = $bag->get(params->{key});
		return "Nothing to approve." unless $data;

		$data->{approved} = 1;
		$bag->add($data);
		try {
			email {
				to => $data->{user_email},
				subject => h->config->{request_copy}->{subject},
				body => export_to_string(
					{ key => params->{key} },
					'Template',
					template => 'views/email/req_copy_approve.tt'),
			};
		} catch {
			error "Could not send email: $_";
		}
		return "Thank you for your approval. The user will be notified to download the file.";
	};

=head2 GET /rc/deny/:key

Author refuses the request for a copy. Email will be sent
to user. Delete request key from database.

=cut
	get 'deny/:key' => sub {
		forward '/rc/deny', {key => params->{key}}, {method => 'POST'};
	};

	post '/deny' => sub {
		my $bag = Catmandu->store->bag('request');
		my $data = $bag->get(params->{key});
		return "Nothing to deny." unless $data;

		$bag->delete(params->{key});
		try {
			email {
				to => $data->{user_email},
				subject => h->config->{request_copy}->{subject},
				body => export_to_string(
					{},
					'Template',
					template => 'views/email/req_copy_deny.tt'),
			};
		} catch {
			error "Could not send email: $_";
		}
		return "The user will be notified that the request has been denied.";
	};

=head2 GET /rc/:key

User received permission for downloading.
Now get the document if time has not expired yet.

=cut
	get '/:key' => sub {
		my $check = Catmandu->store->bag('request')->get(params->{key});
		if ($check and $check->{approved} == 1) {
			_send_it($check->{record_id}, $check->{file_name});
		} else {
			template 'error',
				{message => "The time slot has expired. You can't download the document anymore."};
		}
	};

};

=head2 GET /download/:id/:file_id

Download a document. Access level of the document
and user rights will be checked before.

=cut
get '/download/:id/:file_id' => sub {

	my ($ok, $file_name) = can_download(
				params->{id},
				params->{file_id},
				session->{user},
				session->{role},
				request->address);
	unless ($ok) {
		status 'access_denied';
		return template 'websites/403',{path =>request->path};
	}

	_send_it(params->{id}, $file_name);
};

# the route
get '/thumbnail/:id' => sub {
    my $id = params->{id};
 
    # get the publication
    if (my $pub = h->publication->get($id)) {
        return status 404 unless $pub->{status} eq 'public'; # check if it's public
        my $files = $pub->{file} || return status 404;
 
        for my $file (@$files) {
            if ($file->{file_name} =~ /^thumbnail\.\w{2,3}$/) { # found the file
                if ($file->{access_level} eq 'closed') {
                    return status 404;
                }
                if ($file->{access_level} eq 'local') { # check if ip is in range
                    return status 401 unless request->address =~ h->config->{private}->{ip_range};
                }
                else {
                	
                	_send_it($id, $file->{file_name});
                }
            }
        }
    }
    status 404;
};

1;
