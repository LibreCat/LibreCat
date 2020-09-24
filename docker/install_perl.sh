#!/bin/bash

# Install a basic perl
git clone https://github.com/tokuhirom/plenv.git /opt/librecat/.plenv
echo 'export PATH="$HOME/.plenv/bin:$PATH"' >> /opt/librecat/.bash_profile
echo 'eval "$(plenv init -)"' >> /opt/librecat/.bash_profile
source /opt/librecat/.bash_profile
git clone https://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/
plenv install -j 9 -D usethreads 5.28.2
plenv global 5.28.2
plenv install-cpanm
cpanm Carton LWP::Protocol::https
plenv rehash

# Install all carton dependencies
cd /opt/librecat
carton

echo 'export LIBRECATHOME=/opt/librecat' >> /opt/librecat/.bash_profile
echo 'export PATH=${LIBRECATHOME}/local/bin:${PATH}' >> /opt/librecat/.bash_profile
echo 'export PERL5LIB=${LIBRECATHOME}/local/lib/perl5:${LIBRECATHOME}/lib' >> /opt/librecat/.bash_profile
