requires 'perl', 'v5.10.1';

on 'test', sub {
  requires 'Test::Deep', '0.112';
  requires 'Test::Exception', '0.32';
  requires 'Test::More', '1.001003';
};

# Catmandu
requires 'Catmandu';
requires 'Catmandu::Store::Elasticsearch';
requires 'Catmandu::Store::MongoDB';
requires 'Catmandu::BibTeX';
requires 'Catmandu::Importer::XML';
requires 'Catmandu::Importer::ArXiv';
requires 'Catmandu::Importer::Inspire';
requires 'Catmandu::Importer::EuropePMC';
requires 'Catmandu::Importer::CrossRef';

#Dancer
requires 'Dancer';
requires 'Dancer::Plugin';
requires 'Dancer::FileUtils';
requires 'Dancer::Plugin::Catmandu::OAI';
requires 'Dancer::Plugin::Catmandu::SRU';
requires 'Dancer::Plugin::Email';
requires 'Dancer::Plugin::Auth::Tiny';
requires 'Dancer::Session::Catmandu';
requires 'Template';
requies 'Template::Plugin::Date';
requires 'Template::Plugin::JSON';
requires 'Furl';
requires 'HTML::Entities';
requires 'Net::LDAP';
requires 'Net::LDAPS';

#Plack
requires 'Plack::Middleware::ReverseProxy';
requires 'Dancer::Middleware::Rebase';

# others
requires 'DateTime';
requires 'Hash::Merge';
requires 'Try::Tiny';
requires 'Sys::Hostname::Long';
requires 'JSON';
