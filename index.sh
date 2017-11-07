#!/bin/bash

TMPDIR=/tmp/librecat-$$
CMD=$1

function whoops {
    DATE=`date`
    error "caught an $? at line $1 exiting"
    exit 2
}

function f_create_demo {
    echo "Creating index..."
    carton exec "yes | bin/librecat index initialize" || return $?
    echo "user..."
    carton exec "bin/librecat user add devel/user.yml" || return $?
    echo "publication..."
    carton exec "bin/librecat publication add devel/publications.yml" || return $?
    echo "department..."
    carton exec "bin/librecat department tree devel/department-tree.yml" || return $?
    echo "project..."
    carton exec "bin/librecat project add devel/project.yml" || return $?
    echo "Done"
}

function f_init {
    echo "Creating index..."
    carton exec "bin/librecat index initialize" || return $?
    echo "Done"
}

function f_drop {
    echo "Dropping index..."
    carton exec "bin/librecat index purge" || return $?
    echo "Done"
}

function f_drop_backup {
    echo "Dropping backup..."
    echo "ids..."
    carton exec "bin/librecat delete main --bag data" || return $?
    echo "user..."
    carton exec "bin/librecat delete main --bag user" || return $?
    echo "publication..."
    carton exec "bin/librecat delete main --bag publication" || return $?
    echo "department..."
    carton exec "bin/librecat delete main --bag department" || return $?
    echo "project..."
    carton exec "bin/librecat delete main --bag project" || return $?
    echo "research_group..."
    carton exec "bin/librecat delete main --bag research_group" || return $?
    echo "Done"
}

function f_drop_version {
    echo "Dropping versions..."
    echo "user..."
    carton exec "bin/librecat delete main --bag user_version" || return $?
    echo "publication..."
    carton exec "bin/librecat delete main --bag publication_version" || return $?
    echo "department..."
    carton exec "bin/librecat delete main --bag department_version" || return $?
    echo "project..."
    carton exec "bin/librecat delete main --bag project_version" || return $?
    echo "research_group..."
    carton exec "bin/librecat delete main --bag research_group_version" || return $?
    echo "Done"
}

function f_drop_audit {
    echo "Dropping audit..."
    echo "audit..."
    carton exec "bin/librecat delete main --bag audit" || return $?
    echo "Done"
}

function f_drop_reqcopy {
    echo "Dropping reqcopy..."
    echo "reqcopy..."
    carton exec "bin/librecat delete main --bag reqcopy" || return $?
    echo "Done"
}

function f_reindex {
    echo "Reindex:"
    carton exec "bin/librecat index switch" || return $?
    echo "Done"
}

function f_export {
    echo "Exporting index..."

    mkdir -p ${TMPDIR}

    echo "user..."
    carton exec "bin/librecat user list" > ${TMPDIR}/user.yml || return $?
    echo "publication..."
    carton exec "bin/librecat publication list" > ${TMPDIR}/publications.yml || return $?
    echo "department..."
    carton exec "bin/librecat department list" > ${TMPDIR}/department.yml || return $?
    echo "project..."
    carton exec "bin/librecat project list" > ${TMPDIR}/project.yml || return $?
    echo "research_group..."
    carton exec "bin/librecat research_group list" > ${TMPDIR}/research_group.yml || return $?

    cd ${TMPDIR}

    OUTFILE=/tmp/librecat-index-export.$$.zip
    zip ${OUTFILE} *

    cd -

    rm -rf ${TMPDIR}

    echo "Output ready in: ${OUTFILE}"
    echo "Done"
}

function f_import {
    echo "Importing index..."
    FILE=$2

    if [ "${FILE}" == "" ]; then
        echo "Need a zipfile"
        echo "usage: $0 index zipfile"
        exit 1
    fi

    mkdir -p ${TMPDIR}

    cd ${TMPDIR}

    unzip ${FILE}

    cd -

    echo "user..."
    carton exec "bin/librecat user add" ${TMPDIR}/user.yml || return $?
    echo "publications..."
    carton exec "bin/librecat publication add" ${TMPDIR}/publications.yml || return $?
    echo "department..."
    carton exec "bin/librecat department add" ${TMPDIR}/department.yml || return $?
    echo "project..."
    carton exec "bin/librecat project add" ${TMPDIR}/project.yml || return $?
    echo "research_group..."
    carton exec "bin/librecat research_group add" ${TMPDIR}/research_group.yml || return $?

    rm -rf ${TMPDIR}

    echo "Done"
}

confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure? [y/N]} " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

trap 'whoops $LINENO' ERR

case "${CMD}" in
    demo)
        f_create_demo
        ;;
    create)
        echo "You probably mean: '$0 demo'"
        ;;
    init)
        f_init
        ;;
    drop)
        confirm "Are you sure you want to drop the search index? [y/N]" && f_drop
        ;;
    drop_backup)
        confirm "Are you sure you want to drop the main data? [y/N]" && f_drop_backup
        ;;
    drop_version)
        confirm "Are you sure you want to drop the version data? [y/N]" && f_drop_version
        ;;
    drop_all)
        confirm "Are you sure you want to drop all data? [y/N]" && \
            f_drop && \
            f_drop_backup && \
            f_drop_version
        confirm "Drop audit data? [y/N]" && f_drop_audit
        confirm "Drop reqcopy data? [y/N]" && f_drop_reqcopy
        ;;
    reindex)
        f_reindex
        ;;
    export)
        f_export
        ;;
    import)
        f_import
        ;;
    *)
        echo "usage: $0 {init|reindex|drop|drop_backup|drop_version|drop_all|export|import|demo}"
        exit 1
esac
