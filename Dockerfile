FROM centos:7

MAINTAINER LibreCat community <librecat-dev@lists.uni-bielefeld.de>

RUN yum install -y gcc make patch automake autoconf ; \
    yum install -y epel-release ; \
    yum install -y expat-devel expat openssl-devel openssl libxml2 libxml2-devel ; \
    yum install -y automake libxslt libxslt-devel gdbm gdbm-devel ImageMagick ghostscript ; \
    yum install -y libgearman libgearman-devel gearmand java-1.8.0-openjdk ; \
    yum install -y mailx git mariadb mariadb-devel which sudo psmisc

# Create user librecat/librecat
RUN useradd --home-dir /home/librecat --password='$1$uRpVBuK8$TiWQStBKbKIDkovAoZnOo.' librecat

# Create install directory
RUN mkdir -p /opt/librecat
RUN mkdir -p /home/librecat
RUN chown -R librecat:librecat /opt/librecat
RUN chown -R librecat:librecat /home/librecat

# Install perl
USER librecat
ADD docker/install_perl.sh /tmp/install_perl.sh
RUN bash /tmp/install_perl.sh

# Install perl dependencies
WORKDIR /opt/librecat
ADD cpanfile /opt/librecat/cpanfile
RUN bash -l carton

# ---End slow part -------------------------------------------------------------

USER root

# Copy the source code
COPY --chown=librecat:librecat . /opt/librecat

# Configuration
COPY docker /tmp/docker
RUN echo "- /tmp/docker" > /opt/librecat/layers.yml
RUN mv /opt/librecat/config/catmandu.local.yml-example /tmp/docker/config/a_local_config.yml
RUN chown -R librecat:librecat /tmp/docker
RUN mkdir -p /etc/sudoers.d/
RUN echo "librecat     ALL=(ALL)       ALL" > /etc/sudoers.d/10_librecat

# Wait for stuff
ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.2.1/wait /wait
RUN chmod +x /wait

# Start
USER librecat
CMD /wait && bash -l /opt/librecat/docker/boot.sh
