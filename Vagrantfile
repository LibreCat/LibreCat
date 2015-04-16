$script = <<SCRIPT
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | tee /etc/apt/sources.list.d/mongodb.list

apt-get update

apt-get install -y curl unzip wget git vim mongodb-10gen elasticsearch build-essential
apt-get install -y libexpat1-dev libxml2-dev libxslt1-dev libgdbm-dev libssl-dev openssl cpanminus
service elasticsearch start
service mongodb start

mkdir -p /opt/perlbrew/perl5
export PERLBREW_ROOT=/opt/perlbrew/perl5
cpanm App::perlbrew

perlbrew init
perlbrew install-cpanm
perlbrew install --notest perl-5.20.1
chown root:vagrant /opt/perlbrew/perl5 -R
chmod -R g+w /opt/perlbrew/perl5

echo 'export PERLBREW_ROOT=/opt/perlbrew/perl5' >> /etc/profile.d/perlbrew.sh
echo 'export PATH=/opt/perlbrew/perl5/bin:/opt/perlbrew/perl5/perls/perl-5.20.1/bin:$PATH' >> /etc/profile.d/perlbrew.sh
chmod +x /etc/profile.d/perlbrew.sh
. /etc/profile.d/perlbrew.sh
cpanm Starman

cd /vagrant

cpanm --installdeps .
perl bin/genAllForms.pl

catmandu import YAML to authority --bag admin < demo/user.yml
catmandu import YAML to search --bag publication <demo/publication.yml
catmandu import YAML to authority --bag department <demo/department.yml
starman bin/app.pl
SCRIPT


Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/trusty64"
    config.vm.box_url = "https://atlas.hashicorp.com/ubuntu/boxes/trusty64"
    config.vm.network :forwarded_port, guest: 5000, host: 5000
    config.vm.network :forwarded_port, guest: 8080, host: 8080
#    config.vm.network :forwarded_port, guest: 27017, host: 27017
#    config.vm.network :forwarded_port, guest: 9200, host: 9200
#    config.vm.network :forwarded_port, guest: 9300, host: 9300
    config.vm.provision "shell", inline: $script

end
