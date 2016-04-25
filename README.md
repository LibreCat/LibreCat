# LibreCat - the new repository software powered by Catmandu

## This software is under heavy development.

### Prereqs

These are the installation instructions to install LibreCat on 6.X

Install the following packages with 'yum install':

- expat-devel 
- expat 
- openssl-devel 
- openssl 
- libxml2 
- libxml2-devel 
- libxslt 
- libxslt-devel 
- gdbm 
- gdbm-devel 
- ImageMagick 
- mysql 
- mysql-server 
- mysql-devel 
- mysql-libs
- libgearman
- libgearman-devel
- gearmand

Install the MySQL database:

```
chkconfig --level 2345 mysqld on
service mysqld start
/usr/bin/mysqladmin -u root password '<NEWPASSWORD>'
``` 

Install the Gearman daemon:

```
chkconfig --level 2345 gearmand on
service gearmand start
```

Install a 1.4.X version of ElasticSearh

```
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
```

Edit your .profle and specify the path to your LibreCat installation:

```
#Edit .profile add 
# export LIBRECATHOME=~/LibreCat
# export PERLHOME=/usr
# export PATH=${LIBRECATHOME}/local/bin:${PERLHOME}/bin:${PATH}
# export PERL5LIB=${LIBRECATHOME}/local/lib/perl5:${LIBRECATHOME}/lib
source ~/.profile
```

Go into the LibreCat directory and install all packages with Carton:

```
cd $LIBRECATHOME
cpan App::cpanminus
cpanm Carton
carton install
```

Create the MySQL databases and tables:

```
mysql -u root -p < devel/mysql.sql
mysql -u root -p librecat_system < devel/librecat_system.sql
mysql -u root -p librecat_backup < devel/librecat_backup.sql
mysql -u root -p librecat_requestcopy < devel/librecat_requestcopy.sql
mysql -u root -p librecat_metrics < devel/librecat_metrics.sql
```

Generate the GUI forms:

```
bin/generate_forms.pl
```

Create a basic setup of the database:

```
./index.sh drop
./index.sh create
```

Create a copy of the local settings and change it as needed:

```
cp catmandu.local.yml-example catmandu.local.yml
```

Boot the development server
Your application is now running on http://localhost:5001
```
./boot.sh
```