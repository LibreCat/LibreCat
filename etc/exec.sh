#!/bin/bash
#
# Bash script used for executing crontab commands
#
# E.g. bin/exec.sh bin/librecat publication export

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd ${INSTALL_DIR}/..

if [ ! -r env.sh ]; then
    echo "error - need a ${INSTALL_DIR}/env.sh!"
    exit 2
else
    source env.sh
fi

carton exec "$@"
