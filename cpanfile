requires 'perl', 'v5.10.1';

on 'test' => sub {
    requires 'Test::Lib';
    requires 'Test::More';
    requires 'Test::TCP';
    requires 'Test::Exception';
    requires 'Test::WWW::Mechanize';
    requires 'Dancer::Test';
    requires 'File::Slurp';
    requires 'IO::File';
    requires 'File::Path';
};

requires 'Business::ISBN', 0;
requires 'Search::Elasticsearch', '==1.19';

# Catmandu
requires 'Catmandu', '>=1.0002';
requires 'Catmandu::Exporter::Table';
requires 'Catmandu::Store::ElasticSearch';
requires 'Catmandu::Store::MongoDB', '>=0.0403';
requires 'Catmandu::DBI';
requires 'Catmandu::BibTeX';
requires 'Catmandu::XML';
requires 'Catmandu::ArXiv';
requires 'Catmandu::Inspire';
requires 'Catmandu::EuropePMC';
requires 'Catmandu::CrossRef';
requires 'Catmandu::Importer::getJSON';
requires 'Catmandu::Identifier', '>=0.05';
requires 'Catmandu::RIS', '>=0.04';

#Dancer
requires 'Dancer';
requires 'Dancer::Plugin';
requires 'Dancer::FileUtils';
requires 'Dancer::Plugin::Catmandu::OAI';
requires 'Dancer::Plugin::Catmandu::SRU';
requires 'Dancer::Plugin::Email';
requires 'Dancer::Plugin::Auth::Tiny';
requires 'Dancer::Plugin::DirectoryView';
requires 'Dancer::Plugin::StreamData';
requires 'Dancer::Session::Catmandu';
requires 'Template';
requires 'Template::Plugin::Date';
requires 'Template::Plugin::JSON';
requires 'Furl';
requires 'HTML::Entities';

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
requires 'Business::ISBN10';
requires 'Business::ISBN13';
requires 'App::bmkpasswd', '2.010001';
requires 'DateTime';
requires 'DBD::mysql';
requires 'Hash::Merge';
requires 'Try::Tiny';
requires 'Crypt::Digest::MD5';
requires 'Crypt::SSLeay';
requires 'File::Basename';
requires 'XML::RSS';
requires 'YAML::XS';
requires 'YAML';
requires 'JSON::MaybeXS';
requires 'Log::Log4perl';
requires 'Log::Any::Adapter';
requires 'Log::Any::Adapter::Log4perl';
requires 'Getopt::Long';
requires 'URL::Encode';
requires 'Encode';
requires 'Term::ReadKey';
requires 'Net::LDAP';
requires 'Net::LDAPS';
requires 'Email::Sender::Simple';
requires 'REST::Client';
requires 'Data::Uniqid';

requires 'Module::Install';
requires 'Gearman::XS', '0.15';
requires 'Net::Telnet::Gearman';
requires 'Proc::Launcher', '0.0.35';
requires 'Path::Tiny', '0.052';
requires 'String::CamelCase';

requires 'MIME::Types','0';
requires 'Catmandu::BagIt' , '>=0.12';

requires 'Catmandu::Store::FedoraCommons';
requires 'IO::All';
requires 'Catmandu::Validator::JSONSchema','0.11';
