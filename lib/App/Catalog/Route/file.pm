package App::Catalog::Route::file;

use Catmandu::Sane;
use Dancer qw/:syntax request/;
use App::Catalog::Helper;
use DateTime;
use Try::Tiny;

# some helpers
##############
sub send {
	my ($id, $file_name) = @_;
	my $path_to_file = h->config->{upload_dir} ."/id/$file_name";
	return Dancer::send_file($path_to_file, streaming => 1);
}

sub calc_date {
	my $dt = DateTime->now();
	my $date_expires = $dt->add(days => h->config->{request_copy}->{period})->ymd;
	return $date_expires;
}

# Request-a-copy
################
prefix '/requestcopy' => sub {

	# step one: user requests for document
	# send mail to author and wait for approval
	post '/requestcopy/:id/:file_id' => sub {
		my $conf = h->config->{request_copy};
		my $bag = 'x';

		my $stored = $bag->add({
			record_id => params->{id},
			file_id => params->{id},
			date_expires => calc_date;
			email => params->{email};
			})
		my $key = $stored->{_id};
		my $mail_body = 
		"The publication '$pub->{title}' has been requested by params->{name} (params->{email}).\n
		To approve this request click on the link below:\n\n" .
		h->host ."/requestcopy/approve/" . $key ."\n\n 
		If you want to deny this request click on the following link:\n\n"
		h->host ."/requestcopy/deny/" . $key ."\n\n
		Your PUB system";
		try {
			email {
				to => "author@home.com",
				subject => $conf->{subject},
				body => $mail_body;
			};
		} catch {
			error "Could not send email: $_";
		}
	};

	# author approves request
	get '/approve/:key' => sub {
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
				subject => $conf->{subject},
				body => $mail_body;
			};
		} catch {
			error "Could not send email: $_";
		}
	};

	# author denies request
	get '/deny/:key' => sub {
		my $data = $bag->get(params->{key});
		$bag->delete(params->{key});
		my $mail_body = "Your request has been denied by the author.\n\n
		Your PUB system";
		try {
			email {
				to => $data->{email},
				subject => $conf->{subject},
				body => $mail_body;
			};
		} catch {
			error "Could not send email: $_";
		}
	};

	# user download approved request
	get '/download/:key' => sub {
		my $check = h->getPermission(params->{key});
		if ($check->[0]->{approved} == 1) {
			send($check->{id}, $check->{file_id});
		} else {
			template 'error', {message => "The time slot has expired. You can't download the document anymore."}
		}
	};

};

get '/download/:id/:file_id' => sub {
	
	my $pub = edit_publication(params->{id});
	my $access = $pub->{file}->{params->{file_id}}->{access_level};

	if ($access eq 'open_access') {
		send(params->{id}, $file_name);
	} elsif (exists session->{user} && session->{role} eq 'admin') {
		send(params->{id}, $file_name);
	}

	my $ip = request->remote_adress;
	if ($access eq 'unibi' && $ip =~ /^129.70/) {
		send(params->{id}, $file_name);
	} 

	my $account = h->getAccount(session->{user})->[0];
	my $role = session->{role};

	if ($access eq 'admin' && ($role eq 'reviewer' || $role eq 'data_manager') {

		my $access_ok;
		foreach my $item (@{$account->{department}}) {
			if (grep ($item, @{$pub->{department}})) {
				$access_ok = 1;
			}
		}
		
		if ($access_ok)) {
			send(params->{id}, $file_name);
		} else {
			template 'error', {message => "Something went wrong. You don't have permission to see this document."};
		}
	} elsif ($access eq 'admin' && role eq 'user') {
		my $access_ok;
		foreach my $item (@{$pub->{author}}) {
			if ($account->{_id} == $item) {
				my $access_ok = 1;
			}
		} 
		
		if ($access_ok)) {
			send(params->{id}, $file_name);
		} else {
			template 'error', {message => "Something went wrong. You don't have permission to see this document."};
		}
	} else {
		template 'error', {message => "Something went wrong. You don't have permission to see this document."};
	}

};


1;
