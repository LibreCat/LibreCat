package LibreCat::Hook::publication_change_type;

use Catmandu::Sane;
use Catmandu::Fix;
use Moo;

has fixer => (is => 'lazy', handles => [qw(fix)]);

sub _build_fixer {
    Catmandu::Fix->new(
        fixes => [
            'form2schema(publication_identifier)',
            'form2schema(external_id)',
            'page_range_number()',
            'clean_preselects()',
            'split_field(nasc, " ; ")',
            'split_field(genbank, " ; ")',
            'split_field(keyword, " ; ")',
            'vacuum()'
        ]
    );
}

1;
