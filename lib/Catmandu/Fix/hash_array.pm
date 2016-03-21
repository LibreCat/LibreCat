package Catmandu::Fix::hash_array;

use Catmandu::Sane;
use Catmandu::Util qw(:array);
use App::Helper;
use Moo;

sub fix {
    my ($self, $data) = @_;

    my $conf = h->config;
    my $tmp_type;
    if ($data->{type} =~ /^bi[A-Z]/) {
        $tmp_type = "bithesis";
    } else {
        $tmp_type = lc($data->{type});
    }
    my $fields = $conf->{forms}->{publicationTypes}->{$tmp_type}->{fields};

    foreach my $key (keys %$data){
        my $ref = ref $data->{$key};
        my $array_field = $conf->{forms}->{array_field};

        if($ref ne "ARRAY" and array_includes($array_field,$key)){
            $data->{$key} = [$data->{$key}];
        }
        if($ref eq "ARRAY" and !array_includes($array_field,$key)){
            $data->{$key} = $data->{$key}->[0];
        }
    }

    return $data;
}

1;
