package LibreCat::App::Catalogue::Controller::Permission::Permissions;

use Catmandu::Sane;
use Catmandu;
use Catmandu::Util qw(:is);
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Carp;
use Exporter qw/import/;

use Moo;

sub can_edit {
    my ( $self, $pub, %opts ) = @_;

    my $user = delete $opts{user};
    my $role = delete $opts{role};

    return 0 unless defined( $user ) && defined( $pub );

    #no restrictions for super_admin
    return 1 if $role eq "super_admin";

    #only super_admin has access to locked publications
    return 0 if $pub->{locked};

    #collect possible person identifiers
    my @person_ids;

    push @person_ids, $pub->{creator}->{id} if is_string( $pub->{creator}->{id} );
    push @person_ids, grep { is_string($_) } map { $_->{_id} } @{ $pub->{author} || [] };
    push @person_ids, grep { is_string($_) } map { $_->{_id} } @{ $pub->{editor} || [] };
    push @person_ids, grep { is_string($_) } map { $_->{_id} } @{ $pub->{translator} || [] };

    #match current user on person identifier
    for my $person_id ( @person_ids ) {
        return 1 if $person_id eq $user->{_id};
    }

    #access for role reviewer
    if ( $role eq "reviewer" ) {

        for my $rev ( @{ $user->{reviewer} || [] } ) {

            for my $dep ( @{ $pub->{department} || [] } ) {

                return 1 if $rev->{_id} eq $dep->{_id};

            }

        }

    }

    #access for project_reviewer
    elsif ( $role eq "project_reviewer" ) {

        for my $proj_rev ( @{ $user->{project_reviewer} || [] } ) {

            for my $proj ( @{ $pub->{project} || [] } ) {

                return 1 if $proj_rev->{_id} eq $proj->{_id};

            }

        }

    }
    #access for role data_manager
    elsif ( $role eq "data_manager" ) {

         for my $dm ( @{ $user->{data_manager} || [] } ) {

            for my $dep ( @{ $pub->{department} || [] } ) {

                return 1 if $dm->{_id} eq $dep->{_id};

            }

        }

    }
    #access for role delegate
    elsif ( $role eq "delegate" ) {

        for my $dm ( @{ $user->{delegate} || [] } ) {

            for my $person_id ( @person_ids ) {

                return 1 if $person_id eq $dm;
            }

        }

    }

    #cannot edit
    return 0;
}

sub can_delete {
    my ($self, $pub, %opts) = @_;
    return is_string( $opts{role} ) && $opts{role} eq "super_admin" ? 1 : 0;
}

sub can_delete_file {
    my ($self, $pub, %opts) = @_;
    return 0;
}

sub can_download {
    my ( $self, $pub, %opts ) = @_;

    my $file_id = delete $opts{file_id};
    my $user    = delete $opts{user};
    my $role    = delete $opts{role};
    my $ip      = delete $opts{ip};

    my $ip_range = h->config->{ip_range};
    my $access;
    my $file_name;

    for ( @{ $pub->{file} } ) {

        if ( $_->{file_id} eq $file_id ) {

            $access    = $_->{access_level};
            $file_name = $_->{file_name};
            last;

        }

    }

    return (0,"") unless defined $file_name;
    return (0,"") unless defined $access;

    if ($access eq 'open_access') {
        return (1, $file_name);
    }
    elsif ($access eq 'local' && h->within_ip_range($ip, $ip_range)) {
        return (1, $file_name);
    }
    elsif ($access eq 'closed') {

        # closed documents can be downloaded by user
        #if and only if the user can edit the record
        return (
            $self->can_edit( $pub, user => $user, role =>  $role ),
            $file_name
        );
    }
    return (0, '');
}

package LibreCat::App::Catalogue::Controller::Permission;

my $p = LibreCat::App::Catalogue::Controller::Permission::Permissions->new;

use Catmandu::Sane;
use Dancer qw(:syntax hook);
use Dancer::Plugin;

register p => sub {$p};

hook before_template => sub {

    $_[0]->{p} = $p;

};

register_plugin;

1;
