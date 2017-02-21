package LibreCat::Hook::read_only_fields;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Moo;

sub fix {
    my ($self, $data) = @_;

    h->log->debug("entering read_only_fields() hook");

    my $id = $data->{_id};

    return $data unless defined($id);

    # Admins are allowed to do anything...
    return $data if $self->is_admin($data);

    my $read_only_fields;

    if (
       exists(h->config->{hook}) &&
       exists(h->config->{hook}->{read_only_fields})
    ) {
        $read_only_fields = h->config->{hook}->{read_only_fields};
    }
    else {
        $read_only_fields = [];
    }

    if (my $rec = h->publication->get($id) ) {
        for my $field (@$read_only_fields) {
            h->log->debug("updating field $field...");
            $data->{$field} = $rec->{$field} if $rec->{$field};
        }
    }
    else {
        h->log->error("don't find a publication for id `$id'");
    }

    $data;
}

sub is_admin {
    my ($self,$data) = @_;

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

=cut
