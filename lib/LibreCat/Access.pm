package LibreCat::Access;

use Catmandu::Util qw(:is);
use Catmandu::Fix::vacuum as => 'vacuum';
use Moo;

has allowed_user_id         => (is => 'ro' , default => sub { [] });
has allowed_user_role       => (is => 'ro' , default => sub { [] });
has publication_allow       => (is => 'ro');
has publication_deny        => (is => 'ro');

# Return 1 when the person_id is available in one of the
# publication fields given by 'allowed_user_id'.
# E.g. when allowed_user_id => [creator] ,
#  then the $person_id should match $pub->{creator}->{id}.
# E.g. when allowed_user_id => [author] ,
#  then the $person_id should match $pub->{author}->[*]->{id}.
sub by_user_id {
    my ($self, $pub, $user) = @_;

    return 0 unless $pub && $user;

    my $person_id = $user->{_id};

    return 0 unless $self->is_publication_allowed($pub);
    return 0 if $self->is_publication_denied($pub);

    my $perm_by_user_identity = $self->allowed_user_id // [];

    for my $type (@$perm_by_user_identity) {
        my $identities = $pub->{$type} // [];
        $identities = [$identities] if is_hash_ref $identities;

        INNER: for my $person (@$identities) {
            my $id = $person->{id} // '';
            return 1 if $person_id eq $id;
        }
    }

    return 0;
}

# Return 1 when the roles defined in the person record match
# the publication fields given by allowed_user_role.
# E.g. when the user is a reviewer of one or more departments
#  then the department id of the publication should match
#  the publication record
sub by_user_role {
    my ($self, $pub, $user) = @_;

    return 0 unless $pub && $user;

    return 0 unless $self->is_publication_allowed($pub);
    return 0 if $self->is_publication_denied($pub);

    my $perm_by_user_role = $self->allowed_user_role // [];

    for my $role (@$perm_by_user_role) {
        next unless $user->{$role};

        if ($role eq 'reviewer') {
            for my $id (@{$user->{reviewer}}) {
                for my $iid (@{$pub->{department} // []}) {
                    return 1 if $id->{_id} eq $iid->{_id};
                    for my $tree (@{$iid->{tree} // []}) {
                        return 1 if $id->{_id} eq $tree->{_id};
                    }
                }
            }
        }
        elsif ($role eq 'project_reviewer') {
            for my $id (@{$user->{project_reviewer}}) {
                for my $iid (@{$pub->{project} // []}) {
                    return 1 if $id->{_id} eq $iid->{_id};
                }
            }
        }
        elsif ($role eq 'data_manager') {
            return 0 unless is_same($pub->{type},'research_data');
            for my $id (@{$user->{data_manager}}) {
                for my $iid (@{$pub->{department} // []}) {
                    return 1 if $id->{_id} eq $iid->{_id};
                    for my $tree (@{$iid->{tree} // []}) {
                        return 1 if $id->{_id} eq $tree->{_id};
                    }
                }
            }
        }
        elsif ($role eq 'delegate') {
            my @user_ids = $self->all_user_ids($pub);

            for my $id (@{$user->{delegate}}) {
                for my $iid (@user_ids) {
                    # Delegates are special, the data structure
                    # is a normal array of identifiers
                    return 1 if $id eq $iid;
                }
            }
        }
        else {
            $self->log->error("no role_permission_map for $role!");
        }
    }

    return 0;
}

# Return all the publication user identifiers as defined
# in the allowed_user_id "roles".
sub all_user_ids {
    my ($self, $pub) = @_;

    my $user_ids = $self->allowed_user_id // [];

    my @ids = ();
    for my $field (@$user_ids) {
        my $values = $pub->{$field} // [];
        $values = [ $values ] unless is_array_ref $values;

        for my $identify (@$values) {
            push @ids , $identify->{id} if $identify->{id};
        }
    }

    return @ids;
}

sub is_publication_allowed {
    my ($self,$pub) = @_;
    my $h = $self->clean_hash($self->publication_allow);
    return 1 unless defined($h);
    return $self->publication_match($pub,$h);
}

sub is_publication_denied {
    my ($self,$pub) = @_;
    my $h = $self->clean_hash($self->publication_deny);
    return 0 unless defined($h);
    return $self->publication_match($pub,$h);
}

sub publication_match {
    my ($self,$pub,$conf) = @_;

    return 1 unless $conf;

    my $ret = 0;

    for my $key (keys %$conf) {
        my $value = $conf->{$key};

        next unless defined($value);

        if ($ret == 1) {}
        elsif (is_value($pub->{$key}) && $pub->{$key} =~ /^$value$/) {
            $ret = 1;
        }
        else {
            $ret = 0;
        }
    }

    return $ret;
}

# Remove undefined values from a hash
sub clean_hash {
    my ($self,$hash) = @_;
    return undef unless $hash;
    return undef unless int(keys %$hash) > 0;
    vacuum($hash);
    return $hash;
}


1;

__END__

=pod

=head1 NAME

LibreCat::Access - configurable access roles

=head1 SYNOPSIS

    use LibreCat::Access;

    my $access = LibreCat::Access->new(
        allowed_user_id => [qw(creator author)] ,
        allowed_role_id => [qw(reviewer project_reviewer)] ,
        publication_deny => {
            locked => 1,
            status => 'deleted'
        }
    }
    );

    my $user = h->get_person('1234');

    if ($access->by_user_id($pub,$user)) {
        print "$pub is accessible by $user\n";
    }

    if ($access->by_user_role($pub,$user)) {
        print "$pub is accessible by $user\n";
    }
}

=head1 CONFIGURATION

=head2 allowed_user_id

An array of record fields which should match user identifiers.
Currently supported: creator, author, editor, translator, supervisor

=head2 allowed_role_id

An array of user fields which should match records fields identifying users.
Currently supported: reviewer, project_reviewer, data_manager, delegate

=head2 publication_allow

A hash containing one or more properties a publication must match to be allowed.

=head2 publication_deny

A hash containing one or more properties a publication must not match to be allowed.

=head1 METHODS

=head2 by_user_id($publication, $user)

Return 1 when the publication contains a user_id. Return 0 otherwise.

=head2 by_user_role($publication, $user)

Return 1 when the publication matchs the user roles. Return 0 otherwise.

=cut
