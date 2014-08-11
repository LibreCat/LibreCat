requires 'perl', 'v5.10.1';

# Catmandu
requires 'Catmandu';
requires 'Catmandu::Store::Elasticsearch';
requires 'Catmanud::Store::MongoDB';
requires 'Catmandu::Importer::XML';
requires 'Catmandu::Importer::ArXiv';
requires 'Catmandu::Importer::Inspire';
requires 'Catmandu::Importer::EuropePMC';
requires 'Catmandu::Importer::CrossRef';

#Dancer
requires 'Dancer';
requires 'Dancer::Plugin';
requires 'Dancer::Plugin::Catmandu::OAI';
requires 'Dancer::Plugin::Catmandu::SRU';
requires 'Dancer::Plugin::Email';
requires 'Template';
requires 'Furl';

# others
requires 'DateTime';
requires 'Hash::Merge';
requires 'Try::Tiny';
requires 'Moo';
requires 'Sys::Hostname::Long';

