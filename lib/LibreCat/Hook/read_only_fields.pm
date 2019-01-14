package LibreCat::Hook::read_only_fields;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Moo;

sub fix {
    my ($self, $data) = @_;

    h->log->debug("entering read_only_fields() hook");

    my $id = $data->{_id};

    return $data unless defined($id);

    my $read_only_fields;

    if (   exists(h->config->{hook})
        && exists(h->config->{hook}->{read_only_fields}))
    {
        $read_only_fields = h->config->{hook}->{read_only_fields};
    }
    else {
        $read_only_fields = [];
    }

    # Only admin users are allowed to change a read-only field
    # All other users get a previous copy
    # Read-only fields can't be deleted, not even for an admin user
    if (my $rec = Catmandu->store('main')->bag('publication')->get($id)) {
        for my $field (@$read_only_fields) {
            next unless $rec->{$field};

            if ($data->{$field}) {
                # Copy back the old version..unless we are an admin
                if ($self->is_admin($data)) {
                    h->log->debug("$field is readonly, but we are an admin");
                }
                else {
                    h->log->debug(
                        "$field is readonly, switching back to old version");
                    $data->{$field} = $rec->{$field};
                }
            }
            else {
                # The field is not available, copy back for all types of users
                h->log->debug(
                    "$field not provided, switching back to old version");
                $data->{$field} = $rec->{$field};
            }
        }
    }
    else {
        h->log->error("don't find a publication for id `$id'");
    }

    $data;
}

sub is_admin {
    my ($self, $data) = @_;

    h->log->debug("checking for admin rights");

    my $user_id = $data->{user_id};

    return undef unless $user_id;

    h->log->debug("finding user credentials for `$user_id'");
    my $person = h->get_person($user_id);

    my $super_admin = $person->{super_admin} ? 1 : 0;

    h->log->debug("user super_admin : $super_admin");

    return $super_admin if $super_admin;

    my $reviewer = $person->{reviewer} ? 1 : 0;

    h->log->debug("user reviewer : $reviewer");

    return $reviewer;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::read_only_fields - A hook that makes sure some fields can only be set once or by an admin

=head1 SYNOPSIS

    # in your config
    hook:
      read_only_fields:
        - legacy_id
    hooks:
      publication-update:
        before_fixes:
          - read_only_fields

=head1 DESCRIPTION

With this hooks some fields in your data model can be set to read-only.
These fields are set once and can never be deleted by any user.
Only admins and reviewers can change the content of these fields.

=cut
