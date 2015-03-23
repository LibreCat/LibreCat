requires 'perl', 'v5.10.1';

# Catmandu
requires 'Catmandu';
requires 'Catmandu::Store::ElasticSearch';
requires 'Catmandu::Store::MongoDB';
requires 'Catmandu::Store::DBI';
requires 'Catmandu::BibTeX';
requires 'Catmandu::Importer::XML';
requires 'Catmandu::Importer::ArXiv';
requires 'Catmandu::Importer::Inspire';
requires 'Catmandu::Importer::EuropePMC';
requires 'Catmandu::Importer::CrossRef';
#requires 'Catmandu::Importer::getJSON';

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
requires 'Template::Plugin::Date';
requires 'Template::Plugin::JSON';
requires 'Furl';
requires 'HTML::Entities';
requires 'Net::LDAP';
requires 'Net::LDAPS';

#Plack
requires 'Plack';
requires 'Plack::Middleware::ReverseProxy';
requires 'Dancer::Middleware::Rebase';
requires 'Starman';

# others
requires 'DateTime';
requires 'Hash::Merge';
requires 'Try::Tiny';
requires 'Sys::Hostname::Long';
requires 'Crypt::Digest::MD5';
requires 'YAML::Any';
requires 'JSON';
