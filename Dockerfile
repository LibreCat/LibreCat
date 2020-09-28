FROM centos:7

MAINTAINER LibreCat community <librecat-dev@lists.uni-bielefeld.de>

RUN yum install -y gcc make patch automake autoconf ; \
    yum install -y epel-release ; \
    yum install -y expat-devel expat openssl-devel openssl libxml2 libxml2-devel ; \
    yum install -y automake libxslt libxslt-devel gdbm gdbm-devel ImageMagick ghostscript ; \
    yum install -y libgearman libgearman-devel gearmand java-1.8.0-openjdk ; \
    yum install -y mailx git mariadb mariadb-devel which sudo psmisc

# Copy the source code
ADD . /opt/librecat

# Create user librecat/librecat
RUN useradd --home-dir /opt/librecat --password='$1$uRpVBuK8$TiWQStBKbKIDkovAoZnOo.' librecat

# Set file ownership
RUN chown -R librecat:librecat /opt/librecat

WORKDIR /opt/librecat

# Install perl
USER librecat
ADD docker/install_perl.sh /tmp/install_perl.sh
RUN bash /tmp/install_perl.sh

# Configuration
USER root
COPY docker /opt/librecat/docker
RUN echo "- /opt/librecat/docker" > /opt/librecat/layers.yml
RUN mv /opt/librecat/config/catmandu.local.yml-example /opt/librecat/docker/config/a_local_config.yml
RUN chown -R librecat:librecat /opt/librecat/docker
RUN mkdir -p /etc/sudoers.d/
RUN echo "librecat     ALL=(ALL)       ALL" > /etc/sudoers.d/10_librecat

# Wait for stuff
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.2.1/wait /wait
RUN chmod +x /wait

# Start
USER librecat
CMD /wait && bash -l /opt/librecat/docker/boot.sh
