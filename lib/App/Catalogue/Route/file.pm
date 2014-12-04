package App::Catalog::Route::file;

=head1 NAME

    App::Catalog::Route::file - routes for file handling:
    upload & download files, request-a-copy.
		All these must be public.

=cut

use Catmandu::Sane;
use Catmandu qw/export_to_string/;
use Dancer ':syntax';
use Dancer::Request;
use App::Helper;
use App::Catalog::Controller::Permission qw/can_download/;
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

sub get_file_name {
	my ($pub_id, $file_id) = @_;
	my $rec = h->publication->get($pub_id);
	if($rec->{file} and ref $rec->{file} eq "ARRAY"){
		my $matching_items = (grep {$_->{file_id} eq $file_id} @{$rec->{file}})[0];
		return $matching_items->{file_name};
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
		my $file_name = get_file_name(params->{id}, params->{file_id});
		my $date_expires = calc_date();
		
		my $query = {
			"approved"     => "1",
			"file_id"      => params->{file_id},
			"file_name"    => $file_name,
			"date_expires" => $date_expires,
			"record_id"    => params->{id}
		};
		my $hits = $bag->search(
		    query => $query,
		    limit => 1
		);
		
		if($hits->{hits}->[0]){
			my $rec = $hits->{hits}->[0];
			return h->host . ":3000/requestcopy/download/" . $rec->{_id};
		}
		else{
			my $stored = $bag->add({
				record_id => params->{id},
				file_id => params->{file_id},
				file_name => $file_name || "",
				date_expires => $date_expires,
				email => params->{email} || "",
				approved => params->{approved} || 0,
			});
			
			if(params->{email}){
				my $pub = edit_publication(params->{id});
				my $mail_body = export_to_string({
					title => $pub->{title},
					user_name => params->{user_name},
					key => $stored->{_id},
				},
				'Template',
				template => 'email/req_copy.tt');
				try {
					email {
						to => params->{email},
						subject => h->config->{request_copy}->{subject},
						body => $mail_body,
					};
				} catch {
					error "Could not send email: $_";
				}
			}
			else {
				return h->host . "/requestcopy/download/" . $stored->{_id};
			}
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
		my $mail_body = export_to_string({
			key => param->{key}
			},
			'Template',
			template => 'email/req_copy_approve.tt');
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
	get '/deny/:key' => sub {
		my $bag = 'x';
		my $data = $bag->get(params->{key});
		$bag->delete(params->{key});
		my $mail_body = export_to_string({}, 'Template', template => 'email/req_copy_refuse.tt');
		try {
			email {
				to => $data->{email},
				subject => h->config->{request_copy}->{subject},
				body => $mail_body,
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
		my $check = Catmandu->store->bag('request')->get(params->{key});
		if ($check and $check->{approved} == 1) {
			send_it($check->{record_id}, $check->{file_name});
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

	my ($ok, $file_name) = can_download(
				params->{id},
				params->{file_id},
				session->{login},
				session->{role},
				request->address); # or maybe request->remote_host?
	return '403' unless $ok;

	send_it(params->{id}, $file_name);
};

1;

__END__
	# my $access = "admin";
	#
	# foreach my $file (@{$pub->{file}}){
	# 	if($file->{file_id} eq params->{file_id}){
	# 		$access = $file->{access_level};
	# 		$file_name = $file->{file_name};
	# 		last;
	# 	}
	# }
	#
	# # openAccess
	# if ($access eq 'openAccess') {
	# 	send_it(params->{id}, $file_name);
	# } elsif (exists session->{user} && session->{role} eq 'admin') {
	# 	send_it(params->{id}, $file_name);
	# }
	#
	# # unibi
	# my $ip = request->{remote_adress};
	# if ($access eq 'unibi' && $ip =~ /^129.70/) {
	# 	send_it(params->{id}, $file_name);
	# }
	#
	# # user/admin/reviewer
	# my $account = h->getAccount(session->{user})->[0];
	# my $role = session->{role};
	#
	# if ($access eq 'admin' && ($role eq 'reviewer' || $role eq 'data_manager')) {
	#
	# 	my $access_ok;
	# 	if($role eq "reviewer"){
	# 		foreach my $item (@{$account->{reviewer}}){
	# 			if(grep ($item, @{$pub->{department}})){
	# 				$access_ok = 1;
	# 			}
	# 		}
	# 	}
	# 	elsif($role eq "data_manager"){
	# 		if($pub->{type} eq "researchData" or $pub->{type} eq "dara"){
	# 			foreach my $item (@{$account->{department}}) {
	# 				if (grep ($item, @{$pub->{department}})) {
	# 					$access_ok = 1;
	# 				}
	# 			}
	# 		}
	# 	}
	#
	#
	# 	if ($access_ok) {
	# 		send_it(params->{id}, $file_name);
	# 	} else {
	# 		template 'error', {message => "Something went wrong. You don't have permission to see this document."};
	# 	}
	# } elsif ($access eq 'admin' && session->{role} eq 'user') {
	# 	my $access_ok;
	# 	foreach my $item (@{$pub->{author}}) {
	# 		if ($account->{_id} == $item->{id}) {
	# 			$access_ok = 1;
	# 		}
	# 	}
	#
	# 	if ($access_ok) {
	# 		send_it(params->{id}, $file_name);
	# 	} else {
	# 		template 'error', {message => "Something went wrong. You don't have permission to see this document."};
	# 	}
	# } else {
	# 	template 'error', {message => "Something went wrong. You don't have permission to see this document."};
	# }
