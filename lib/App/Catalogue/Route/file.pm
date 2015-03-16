package App::Catalogue::Route::file;

=head1 NAME

    App::Catalogue::Route::file - routes for file handling:
    upload & download files, request-a-copy.
		All these must be public.

=cut

use Catmandu::Sane;
use Catmandu qw/export_to_string/;
use Dancer ':syntax';
use Dancer::Request;
use App::Helper;
use App::Catalogue::Controller::Permission qw/can_download/;
use DateTime;
use Try::Tiny;
use Dancer::Plugin::Auth::Tiny;

# some helpers
##############
sub send_it {
	my ($id, $file_name) = @_;
	my $dest_dir = h->get_file_path($id);
	my $path_to_file = path($dest_dir, $file_name);
	return Dancer::send_file($path_to_file, system_path => 1);
}

sub calc_date {
	my $dt = DateTime->now();
	my $date_expires = $dt->add(days => h->config->{request_copy}->{period})->ymd;
	return $date_expires;
}

sub get_file_info {
	my ($pub_id, $file_id) = @_;
	my $rec = h->publication->get($pub_id);
	if($rec->{file} and ref $rec->{file} eq "ARRAY"){
		my $matching_items = (grep {$_->{file_id} eq $file_id} @{$rec->{file}})[0];
		return $matching_items;
	}
}

=head1 PREFIX /requestcopy

    Prefix for the feature 'request-a-copy'

=cut
prefix '/requestcopy' => sub {

=head2 GET requestcopy/:id/:file_id

    Request a copy of the publication. Email will be sent
    to the author.

=cut
	post '/:id/:file_id' => sub {
		my $bag = Catmandu->store->bag('request');
		my $file = get_file_info(params->{id}, params->{file_id});
		return unless $file->{request_a_copy} == 1;

		my $date_expires = calc_date();

		my $query = {
			"approved"     => "1",
			"file_id"      => params->{file_id},
			"file_name"    => $file->{file_name},
			"date_expires" => $date_expires,
			"record_id"    => params->{id}
		};
		my $hits = $bag->search(
		    query => $query,
		    limit => 1
		);

		if($hits->{hits}->[0]){
			my $obj = $hits->{hits}->[0];
			return h->host . "/rc/" . $obj->{_id};
		}
		else{
			my $stored = $bag->add({
				record_id => params->{id},
				file_id => params->{file_id},
				file_name => $file->{file_name},
				date_expires => $date_expires,
				email => params->{user_email},
				approved => params->{approved} || 0,
			});

			my $file_creator_email = h->getAccount($file->{creator})->[0]->{email};

			if(params->{user_email}){
				my $pub = h->publication->get(params->{id});
				my $mail_body = export_to_string({
					title => $pub->{title},
					user_name => params->{user_name},
					key => $stored->{_id},
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
				} catch {
					error "Could not send email: $_";
				}
			}
			else {
				return h->host . "/rc/" . $stored->{_id};
			}
		}
	};

=head2 GET /approve/:key

    Author approves the request. Email will be sent
    to user.

=cut
	get '/approve/:key' => sub {
		my $bag = Catmandu->store->bag('request');
		my $data = $bag->get(params->{key});
		return unless $data;

		$data->{approved} = 1;
		$bag->add($data);
		my $mail_body = export_to_string(
			{ key => params->{key} },
			'Template',
			template => 'views/email/req_copy_approve.tt');
		try {
			email {
				to => $data->{user_email},
				subject => h->config->{request_copy}->{subject},
				body => $mail_body;
			};
		} catch {
			error "Could not send email: $_";
		}
	};

=head2 GET /refuse/:key

    Author refuses the request for a copy. Email will be sent
    to user. Delete request key from database.

=cut
	get '/deny/:key' => sub {
		my $bag = Catmandu->store->bag('request');
		my $data = $bag->get(params->{key});
		return unless $data;

		$bag->delete(params->{key});
		my $mail_body = export_to_string({}, 'Template', template => 'views/email/req_copy_refuse.tt');
		try {
			email {
				to => $data->{user_email},
				subject => h->config->{request_copy}->{subject},
				body => $mail_body,
			};
		} catch {
			error "Could not send email: $_";
		}
	};

};


=head2 GET /rc/:key

	User received permission for downloading.
	Now get the document if time has not expired yet.

=cut
get '/rc/:key' => sub {
	my $check = Catmandu->store->bag('request')->get(params->{key});
	if ($check and $check->{approved} == 1) {
		send_it($check->{record_id}, $check->{file_name});
	} else {
		template 'error', {message => "The time slot has expired. You can't download the document anymore."};
	}
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
				request->address); # or maybe request->remote_host?
	return status '403' unless $ok;

	send_it(params->{id}, $file_name);
};

1;
