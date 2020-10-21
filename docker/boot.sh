#!/bin/bash

. /home/librecat/.bash_profile

PLACKUP=${LIBRECAT_PLACKUP:-1}
INIT=${LIBRECAT_INIT:-1}
DEMO=${LIBRECAT_DEMO:-1}
L_ENV=${LIBRECAT_ENV:-development}
L_HOST=${LIBRECAT_HOST:-localhost}
L_PORT=${LIBRECAT_PORT:-5002}
E_HOST=${ELASTIC_HOST:-elasticsearch}
E_PORT=${ELASTIC_PORT:-9200}
M_HOST=${MYSQL_HOST:-mysql}
M_PORT=${MYSQL_PORT:-3306}
M_PASS=${MYSQL_ROOT_PASSWORD:-librecat}

DOCKER_YML=/tmp/docker/config/docker.yml
TEST_YML=/opt/librecat/t/layer/config/docker.yml

# Change local host settings
sed -i "s/uri_base: .*/uri_base: http:\/\/${L_HOST}:${L_PORT}/" ${DOCKER_YML}
sed -i "s/data_source: .*/data_source: \"DBI:mysql:database=librecat_main;host=${M_HOST};port=${M_PORT}\"/" ${DOCKER_YML}
sed -i "s/nodes: .*/nodes: ${E_HOST}:${E_PORT}/"  ${DOCKER_YML}

# Copy these changes also to the test layer
cp ${DOCKER_YML} ${TEST_YML}

# Initialize MySQL and ElasticSearch
if [[ ${INIT} == 1 ]]; then
    # Install mysql credentials
    mysql -u root --password=${M_PASS} -h ${M_HOST} -P ${M_PORT} < /opt/librecat/docker/devel/mysql.sql
    mysql -u root --password=${M_PASS} -h ${M_HOST} -P ${M_PORT} librecat_main < /opt/librecat/devel/librecat_main.sql
    # Intialize elasticsearch
    yes | carton exec "/opt/librecat/index.sh init"

    # Install demo records
    if [[ ${DEMO} == 1 ]]; then
        /opt/librecat/index.sh demo
    fi

    # Generate all forms
    /opt/librecat/bin/librecat generate forms
    /opt/librecat/bin/librecat generate departments
fi

# Install environments
if [[ "${L_ENV}" == "development" ]]; then
    if [[ ! -f /opt/librecat/environments/development.yml ]]; then
        cp /opt/librecat/environments/development.yml.default /opt/librecat/environments/development.yml
    fi
elif [[ "${L_ENV}" == "deployment" ]]; then
    if [[ ! -f /opt/librecat/environments/deployment.yml ]]; then
        cp /opt/librecat/environments/deployment.yml.default /opt/librecat/environments/deployment.yml
    fi
fi

# Add a layer when asked
if [[ "${LIBRECAT_LAYER}" != "" ]]; then
    echo "- ${LIBRECAT_LAYER}" >> /opt/librecat/layers.yml
fi

# Boot application
if [[ ${PLACKUP} == 1 ]]; then
    plackup -E ${L_ENV} -R lib,config -s Starman --port ${L_PORT} bin/app.pl
else
    bash -l
fi
