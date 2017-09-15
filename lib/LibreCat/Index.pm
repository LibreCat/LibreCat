package LibreCat::Index;

=head1 NAME

LibreCat::Index - checks status of current index and of index names

=cut

use Catmandu::Sane;
use LibreCat::App::Helper;
use Search::Elasticsearch;


sub get_status {
    my ($self) = @_;

    my $ind_name = Catmandu->config->{store}->{search}->{options}->{index_name};
    my $ind1 = $ind_name ."1";
    my $ind2 = $ind_name ."2";

    my $e = Search::Elasticsearch->new();

    my $alias_exists = $e->indices->exists(index => $ind_name);
    my $ind1_exists = $e->indices->exists(index => $ind1);
    my $ind2_exists = $e->indices->exists(index => $ind2);

    my $alias_exists_for_1 = $e->indices->exists_alias(index => $ind1, name => $ind_name);
    my $alias_exists_for_2 = $e->indices->exists_alias(index => $ind2, name => $ind_name);

    my $result;
    $result->{all_indexes} = [];
    push @{$result->{all_indexes}}, $ind1 if $ind1_exists;
    push @{$result->{all_indexes}}, $ind2 if $ind2_exists;
    $result->{number_of_indexes} = @{$result->{all_indexes}};
    $result->{active_index} = $ind1 if ($ind1_exists and $alias_exists_for_1);
    $result->{active_index} = $ind2 if ($ind2_exists and $alias_exists_for_2);
    $result->{active_index} = $ind_name if (!$ind1_exists and !$ind2_exists and $alias_exists);
    $result->{alias} = $ind_name if $alias_exists;
    return $result;
}

1;
