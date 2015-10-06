sudo yum instal -y expat-devel expat openssl-devel openssl libxml2 libxml2-devel libxslt libxslt-devel gdbm gdbm-devel ImageMagick
sudo yum install -y http://bergson0.ugent.be/exports/perl/perl-5.22.0-1.0-X.x86_64.rpm

cat > /etc/yum.repos.d/mongodb.repo <<EOF
[mongodb]
baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64
gpgcheck=0
enabled=1
name=MongoDB.org repository
EOF

sudo yum install -y mongodb-org mongodb-org-server mongodb-org-shell mongodb-org-mongos mongodb-org-tools

#On a small development box edit /etc/mongod.conf add afer dbpath
# smallfiles=true

service mongod start

cat > /etc/yum.repos.d/elasticsearch-1.4.repo <<EOF
[elasticsearch-1.4]
name=Elasticsearch repository for 1.4.x packages
gpgkey=http://packages.elasticsearch.org/GPG-KEY-elasticsearch
enabled=1
baseurl=http://packages.elasticsearch.org/elasticsearch/1.4/centos
gpgcheck=1
EOF

sudo yum install -y java-1.7.0-openjdk elasticsearch
chkconfig --add elasticsearch
service elasticsearch start

#Edit .profile
# export LIBRECATHOME=~/LibreCat
# export PERLHOME=/opt/perl-5.22.0-x86_64-linux-thread-multi
# export PATH=${LIBRECATHOME}/local/bin:${PERLHOME}/bin:${PATH}
# export PERL5LIB=${LIBRECATHOME}/local/lib/perl5
source ~/.profile

cd LibreCat

#Make sure the cpanfile contains:
# requires 'YAML';
# requires 'JSON';
# requires 'Sys::Hostname::Long';

carton install

perl bin/generate_forms.pl

echo '{"_id": "1", "latest" : "0"}' | catmandu import YAML
catmandu import YAML to search --bag researcher <devel/researcher.yml
catmandu import YAML to search --bag publication <devel/publications.yml

starman bin/app.pl --port 5000 -E development

tar zxvf MathJax.tgz
tar zxvf CommonMark.tgz
