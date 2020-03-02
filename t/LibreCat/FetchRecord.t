use Catmandu;
use warnings FATAL => 'all';
use LibreCat -load => {layer_paths => [qw(t/layer)]};
use Test::More;
use Test::Exception;
use Role::Tiny;

my $pkg;

BEGIN {
    $pkg = 'LibreCat::FetchRecord';
    use_ok $pkg;
}

require_ok $pkg;

{

    package T::FetchRecordWithoutFetch;
    use Moo;

    package T::FetchRecord;
    use LibreCat -self;
    use Moo;
    with $pkg;

    sub fetch {
        my ($self, $id) = @_;
        my $data = {_id => $id};
        my $fixer = librecat->fixer('test.fix');
        $data = $fixer->fix($data);
        return $data;
    }

    package T::FetchRecordWithoutFix;
    use LibreCat -self;
    use Moo;
    with $pkg;

    sub fetch {
        my ($self, $id) = @_;
        my $data = {_id => $id};
        my $fixer = librecat->fixer('nofixfile.fix');
        $data = $fixer->fix($data);
        return $data;
    }
}

throws_ok {
    Role::Tiny->apply_role_to_package(' T::FetchRecordWithoutFetch', $pkg)
}
qr/missing fetch/;

{
    my $fetcher = T::FetchRecord->new;
    ok $fetcher->does('LibreCat::Logger');
    can_ok $fetcher, 'fetch';

    my $res = $fetcher->fetch(1);

    is_deeply $res, {_id => 1, magic => 'hello, world!'},
        "fetch and apply fix";
}

{
    my $fetcher = T::FetchRecordWithoutFix->new;
    ok $fetcher->does('LibreCat::Logger');
    can_ok $fetcher, 'fetch';

    my $res = $fetcher->fetch(1);

    is_deeply $res, {_id => 1}, "fetch with nonexisting fix file";
}

done_testing;
