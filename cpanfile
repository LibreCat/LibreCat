requires 'perl', 'v5.10.1';

# Catmandu
requires 'Catmandu', '>=0.9505';
requires 'Catmandu::Store::ElasticSearch';
requires 'Catmandu::Store::MongoDB';
requires 'Catmandu::Store::DBI';
requires 'DBD::mysql';
requires 'Catmandu::BibTeX';
requires 'Catmandu::Importer::XML';
requires 'Catmandu::Importer::ArXiv';
requires 'Catmandu::Importer::Inspire';
requires 'Catmandu::Importer::EuropePMC';
requires 'Catmandu::Importer::CrossRef';
requires 'Catmandu::Importer::getJSON';
requires 'Catmandu::Identifier', '>=0.03';
requires 'Catmandu::RIS', '>=0.04';

#Dancer
requires 'Dancer';
requires 'Dancer::Plugin';
requires 'Dancer::FileUtils';
requires 'Dancer::Plugin::Catmandu::OAI';
requires 'Dancer::Plugin::Catmandu::SRU';
requires 'Dancer::Plugin::Email';
requires 'Dancer::Plugin::Auth::Tiny';
requires 'Dancer::Plugin::Passphrase';
requires 'Dancer::Plugin::DirectoryView';
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
requires 'Plack::Middleware::Deflater';
requires 'Plack::Middleware::Negotiate', '>= 0.20';
requires 'Plack::Middleware::Debug';
requires 'Plack::Middleware::Debug::Dancer::Settings';
requires 'Starman';

# others
requires 'all';
requires 'DateTime';
requires 'Hash::Merge';
requires 'Try::Tiny';
requires 'Crypt::Digest::MD5';
requires 'XML::RSS';
requires 'YAML::XS';
requires 'JSON::MaybeXS';
requires 'Log::Log4perl';
requires 'Log::Any::Adapter';
requires 'Log::Any::Adapter::Log4perl';
requires 'Getopt::Long';
requires 'URL::Encode';
requires 'Encode';
requires 'Term::ReadKey';
