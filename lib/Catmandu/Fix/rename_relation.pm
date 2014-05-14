package Catmandu::Fix::rename_relation;

use Catmandu::Sane;
use Moo;

my %mappings = (
    belongsToProject       => 'project',
    hasDoi                 => 'doi',
    hasSubject             => 'subject',
    isAuthoredBy           => 'author',
    isCreatedFromAccount   => 'record_creator',
    isEditedBy             => 'editor',
    isQualityControlled	   => 'quality_controlled',
    isPopularScience	   => 'popular_science',	
    isSupervisedBy         => 'supervisor',
    isUnderDepartment      => 'department',
    #translatedWorkAuthoredBy => 'translatedWorkAuthor',
    usesAlternativeMainFile  => 'link',
    usesMainFile             => 'file',
);

my %mappings_sub = (
    isOfType                 => 'type',
    hasLink                  => 'link',
    hasFile                  => 'file',
    isUploadedBy             => 'uploader',
    isOfMaterialRelationType => 'materialRelationType',
);


sub fix {
    my ( $self, $pub, $m ) = @_;
    
    $pub->{_id} = $pub->{oId};
    
    my $um = $m || \%mappings;
    for my $key ( keys %$um ) {
        next unless $pub->{$key};
        $pub->{ $mappings{$key} } = delete $pub->{$key} if $mappings{$key};
    }

    for my $key (keys %mappings_sub) {
        _rename_key($pub, $key, $mappings_sub{$key});
    }    

    
    # Special for related Material
    my @relatedMaterial;
    for my $rel ( qw(relatesFrom relatesTo) ) {
        next unless $pub->{$rel};
        my $rel_list = ref $pub->{$rel} eq 'ARRAY' ? $pub->{$rel} : [$pub->{$rel}];
        foreach my $rm (@{$rel_list}) {
            $rm->{relationRole} = $rel eq 'relatesFrom' ? 'from' : 'to';
        }
        push @relatedMaterial, @$rel_list;
        delete $pub->{$rel};      
    }
    
    $pub->{relatedMaterial}
        = [sort { $a->{"position\u$a->{relationRole}"} <=> $b->{"position\u$b->{relationRole}"} }
            @relatedMaterial] if @relatedMaterial;    

    $pub;
}

#Copied and modified from Hash::RenameKey

sub _rename_key {
    my ($hash, $old, $new) = @_;
    return unless $hash && $old && $new;

    my $recurse = undef;
    $recurse = sub {
        my $input = shift;
        while ( my ($oldkey, $contents) = each %$input ) {
            my $newkey = $oldkey;
            $newkey =~ s/$old/$new/g;
            $recurse->($contents) if ref $contents eq 'HASH';
            if ( ref $contents eq "ARRAY" ) {
                for my $r ( @{$contents} ) {
                    last unless ref $r eq 'HASH'; #shouldn't be mixed HASH ref and SCALAR
                    $recurse->($r);
                }
            }
            $input->{$newkey} = $contents;
            delete $input->{$oldkey} if $oldkey =~ /$old/;
        }
    };
    $recurse->($hash);
    return 1;
}

1;
