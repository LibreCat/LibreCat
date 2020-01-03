package LibreCat::Hook::audit_message;

use Catmandu::Sane;
use LibreCat::App::Helper;
use Dancer qw(:syntax);
use Catmandu;
use LibreCat::Audit;
use Moo;

has name => (is => 'ro', default => sub {''});
has type => (is => 'ro', default => sub {''});
has audit => (
    is => 'ro',
    lazy => 1,
    default => sub { LibreCat::Audit->new(); },
    init_arg => undef
);

sub fix {
    my ($self, $data) = @_;

    my $name = $self->name;
    my $type = $self->type;

    h->log->debug("entering audit_message() hook from : $name ($type)");

    unless ($name =~ /^(publication|import)/) {
        h->log->debug("only handling publication|import hooks");
        return $data;
    }

    my $id      = $data->{_id} // '<new>';
    my $user_id = $data->{user_id} // '<unknown>';
    my $login   = '<unknown>';

    if (defined $data->{user_id}) {
        my $person = h->get_person($user_id);
        $login = $person->{login} if $person;
    }

    my $action;

    if (request && request->path_info()) {
        $action = request->path_info();
    }
    else {
        $action = 'batch';
    }

    my $r = {
        id      => $id,
        bag     => 'publication',
        process => "hook($name)",
        action  => "$action",
        message => "activated by $login ($user_id)",
    };

    h->log->debug("adding audit: " . to_yaml($r));

    unless(
        $self->audit->add( $r )
    ){

        my $current_locale = h->locale();
        h->log->error( "validation audit failed: ".join(",",map {
            $_->localize( $current_locale );
        } @{ $self->audit()->last_errors() }). ". Record: " . to_yaml($r) );

    }

    $data;
}

1;

__END__

=pod

=head1 NAME

LibreCat::Hook::audit_message - a hook to submit audit messages

=head1 SYNPOSIS

    # in your config
    audit: 1

    hooks:
      publication-update:
        before_fixes:
         - audit_message

=cut
