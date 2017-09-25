package LibreCat::Cmd::migrate;

use Catmandu::Sane;
use Catmandu::Util qw(array_includes);
use Catmandu;
use parent qw(LibreCat::Cmd);

sub command_opt_spec {
    my ($class) = @_;
    ();
}

sub command {
    my ($self, $opts, $args) = @_;

    my $warns = 0;

    # check config
    my $store_config = Catmandu->config->{store};

    for my $store (keys %$store_config) {
        my $conf = $store_config->{$store};
        for my $bag (keys %{$conf->{options}{bags}}) {
            my $c = $conf->{options}{bags}{$bag};
            if ($c->{id_generator} && $c->{id_generator} eq 'UniBiDefault') {
                say
                    "Error in config for store $store, bag $bag. id_generator UnibiDefault has been renamed to Incremental.";
                $warns++;
            }
        }
    }

    if (
           !$store_config->{backup}{options}{bags}{session}
        || !$store_config->{backup}{options}{bags}{session}{plugins}
        || !array_includes(
            $store_config->{backup}{options}{bags}{session}{plugins},
            'Datestamps'
        )
        )
    {
        say q|Error in config for store backup. session bag config should be:
  session:
    plugins: ['Datestamps']|;
        $warns++;
    }

    return if $warns;

    # migrate latest publication id from system store to backup store
    my $info_bag = Catmandu->store('main')->bag('info');
    if (!$info_bag->get('publication_id')
        && exists Catmandu->config->{store}{default})
    {
        if (my $rec = Catmandu->store('main')->bag->get('1')) {

            say "Migrating lastest publication id";

            $rec->{_id} = 'publication_id';
            $info_bag->add($rec);
            $info_bag->commit;
            Catmandu->store('main')->bag->delete_all;
            Catmandu->store('main')->bag->commit;
        }
    }

    # migrate sessions from system store to backup store
    my $session_bag = Catmandu->store('main')->bag('session');
    if (   !$session_bag->count
        && Catmandu->config->{store}{default}
        && Catmandu->store('main')->bag('session')->count)
    {
        say "Migrating sessions";

        my $old_session_bag = Catmandu->store('main')->bag('session');
        $session_bag->add_many($old_session_bag);
        $session_bag->commit;
        $old_session_bag->delete_all;
        $old_session_bag->commit;
    }
}

1;

__END__

=pod

=head1 NAME

LibreCat::Cmd::migrate - config checking and database migrations

=cut
