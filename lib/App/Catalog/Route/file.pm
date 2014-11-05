package App::Catalog::Route::file;

=head1 NAME

    App::Catalog::Route::file - routes for file handling:
    upload & download files, request-a-copy.

=cut

use Catmandu::Sane;
use Dancer ':syntax';
use Dancer::Request;
use App::Catalog::Helper;
use DateTime;
use Try::Tiny;

# some helpers
##############
sub send_it {
	my ($id, $file_name) = @_;
	#my $path_to_file = h->config->{upload_dir} ."/$id/$file_name";
	my $path_to_file = path(h->config->{upload_dir}, $id, $file_name);
	return Dancer::send_file($path_to_file,system_path => 1);
}

sub calc_date {
	my $dt = DateTime->now();
	my $date_expires = $dt->add(days => h->config->{request_copy}->{period})->ymd;
	return $date_expires;
}

=head1 PREFIX /requestcopy

    Prefix for the feature 'request-a-copy'

=cut
prefix '/requestcopy' => sub {

=head2 GET requestcopy/:id/:file_id

    Request a copy of the publication. Email will be sent
    to the author.

=cut
	get '/requestcopy/:id/:file_id' => sub {
		my $conf = h->config->{request_copy};
		my $bag = 'x';

		my $stored = $bag->add({
			record_id => params->{id},
			file_id => params->{id},
			date_expires => calc_date,
			email => params->{email},
			});
		my $key = $stored->{_id};
		
		my $pub = edit_publication(params->{id});
		my $mail_body =
		"The publication '$pub->{title}' has been requested by params->{name} (params->{email}).\n
		To approve this request click on the link below:\n\n" .
		h->host ."/requestcopy/approve/" . $key ."\n\n
		If you want to deny this request click on the following link:\n\n" .
		h->host ."/requestcopy/deny/" . $key ."\n\n
		Your PUB system";
		try {
			email {
				to => '',
				subject => h->config->{request_copy}->{subject},
				body => $mail_body,
			};
		} catch {
			error "Could not send email: $_";
		}
	};

=head2 GET /approve/:key

    Author approves the request. Email will be sent
    to user.

=cut
	get '/approve/:key' => sub {
		my $bag = 'x';
		my $data = $bag->get(params->{key});
		$data->{approved} = 1;
		$bag->add($data);
		my $mail_body = "Your request has been approved by the author.\n\n
		Please download the document within the next 10 days from\n"
		. h->host ."requestcopy/download/$data->{_id}\n\n
		Your PUB system";
		try {
			email {
				to => $data->{email},
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
	get '/refuse/:key' => sub {
		my $bag = 'x';
		my $data = $bag->get(params->{key});
		$bag->delete(params->{key});
		my $mail_body = "Your request has been denied by the author.\n\n
		Your PUB system";
		try {
			email {
				to => $data->{email},
				subject => h->config->{request_copy}->{subject},
				body => $mail_body;
			};
		} catch {
			error "Could not send email: $_";
		}
	};

=head2 GET /download/:key

    User received permission for downloading.
    Now get the document if time has not expired yet.

=cut
	get '/download/:key' => sub {
		my $check = h->getPermission(params->{key});
		if ($check->[0]->{approved} == 1) {
			send_it($check->{id}, $check->{file_id});
		} else {
			template 'error', {message => "The time slot has expired. You can't download the document anymore."};
		}
	};

};

=head2 GET /download/:id/:file_id

    Download the document. Access level of the document
    and user rights will be checked before.

=cut
get '/download/:id/:file_id' => sub {

	my $pub = h->publication->get(params->{id});
	my $file_name;
	my $access = "admin"; 
	
	foreach my $file (@{$pub->{file}}){
		if($file->{file_id} eq params->{file_id}){
			$access = $file->{access_level};
			$file_name = $file->{file_name};
			last;
		}
	}
	
	# openAccess
	if ($access eq 'openAccess') {
		send_it(params->{id}, $file_name);
	} elsif (exists session->{user} && session->{role} eq 'admin') {
		send_it(params->{id}, $file_name);
	}
	
	# unibi
	my $ip = request->{remote_adress};
	if ($access eq 'unibi' && $ip =~ /^129.70/) {
		send_it(params->{id}, $file_name);
	}
	
	# user/admin/reviewer
	my $account = h->getAccount(session->{user})->[0];
	my $role = session->{role};

	if ($access eq 'admin' && ($role eq 'reviewer' || $role eq 'data_manager')) {

		my $access_ok;
		if($role eq "reviewer"){
			foreach my $item (@{$account->{reviewer}}){
				if(grep ($item, @{$pub->{department}})){
					$access_ok = 1;
				}
			}
		}
		elsif($role eq "data_manager"){
			if($pub->{type} eq "researchData" or $pub->{type} eq "dara"){
				foreach my $item (@{$account->{department}}) {
					if (grep ($item, @{$pub->{department}})) {
						$access_ok = 1;
					}
				}
			}
		}
		

		if ($access_ok) {
			send_it(params->{id}, $file_name);
		} else {
			template 'error', {message => "Something went wrong. You don't have permission to see this document."};
		}
	} elsif ($access eq 'admin' && session->{role} eq 'user') {
		my $access_ok;
		foreach my $item (@{$pub->{author}}) {
			if ($account->{_id} == $item->{id}) {
				$access_ok = 1;
			}
		}

		if ($access_ok) {
			send_it(params->{id}, $file_name);
		} else {
			template 'error', {message => "Something went wrong. You don't have permission to see this document."};
		}
	} else {
		template 'error', {message => "Something went wrong. You don't have permission to see this document."};
	}

};

1;