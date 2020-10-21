#!/bin/bash

# Install a basic perl
git clone https://github.com/tokuhirom/plenv.git /home/librecat/.plenv
echo 'export PATH="$HOME/.plenv/bin:$PATH"' >> /home/librecat/.bash_profile
echo 'eval "$(plenv init -)"' >> /home/librecat/.bash_profile
source /home/librecat/.bash_profile
git clone https://github.com/tokuhirom/Perl-Build.git /home/librecat/.plenv/plugins/perl-build/
plenv install -j 9 -D usethreads 5.28.2
plenv global 5.28.2
plenv install-cpanm
cpanm Carton LWP::Protocol::https
plenv rehash

echo 'export PERL_CARTON_PATH=/home/librecat/local' >> /home/librecat/.bash_profile
echo 'export LIBRECATHOME=/opt/librecat' >> /home/librecat/.bash_profile
echo 'export PATH=${PERL_CARTON_PATH}/bin:${PATH}' >> /home/librecat/.bash_profile
echo 'export PERL5LIB=${PERL_CARTON_PATH}/lib/perl5:${LIBRECATHOME}/lib' >> /home/librecat/.bash_profile
