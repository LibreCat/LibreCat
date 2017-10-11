#!/bin/bash

TMPDIR=/tmp/librecat-$$
CMD=$1

function f_create {
    echo "Creating index..."
    echo "user..."
    carton exec "bin/librecat user add devel/user.yml"
    echo "publication..."
    carton exec "bin/librecat publication add devel/publications.yml"
    echo "department..."
    carton exec "bin/librecat department tree devel/department-tree.yml"
    echo "project..."
    carton exec "bin/librecat project add devel/project.yml"
    echo "Done"
}

function f_drop {
    echo "Dropping index.."
    carton exec "bin/librecat drop search"
    echo "Done"
}

function f_drop_backup {
    echo "Dropping backup..."
    echo "ids..."
    carton exec "bin/librecat delete main --bag data"
    echo "user..."
    carton exec "bin/librecat delete main --bag user"
    echo "publication..."
    carton exec "bin/librecat delete main --bag publication"
    echo "department..."
    carton exec "bin/librecat delete main --bag department"
    echo "project..."
    carton exec "bin/librecat delete main --bag project"
    echo "research_group..."
    carton exec "bin/librecat delete main --bag research_group"
    echo "Done"
}

function f_drop_version {
    echo "Dropping versions..."
    echo "user..."
    carton exec "bin/librecat delete main --bag user_version"
    echo "publication..."
    carton exec "bin/librecat delete main --bag publication_version"
    echo "department..."
    carton exec "bin/librecat delete main --bag department_version"
    echo "project..."
    carton exec "bin/librecat delete main --bag project_version"
    echo "research_group..."
    carton exec "bin/librecat delete main --bag research_group_version"
    echo "Done"
}

function f_drop_audit {
    echo "Dropping audit..."
    echo "audit..."
    carton exec "bin/librecat delete main --bag audit"
    echo "Done"
}

function f_drop_reqcopy {
    echo "Dropping reqcopy..."
    echo "reqcopy..."
    carton exec "bin/librecat delete main --bag reqcopy"
    echo "Done"
}

function f_drop_metrics {
    echo "Dropping metrics..."
    echo "metrics..."
    carton exec "bin/librecat delete metrics"
    echo "Done"
}

function f_reindex {
    echo "Dropping the search"
    carton exec bin/librecat drop search
    echo "Reindex:"
    echo "user"
    carton exec "bin/librecat copy -v main --bag user to search --bag user"
    echo "publication"
    carton exec "bin/librecat copy -v main --bag publication to search --bag publication"
    echo "department"
    carton exec "bin/librecat copy -v main --bag department to search --bag department"
    echo "project"
    carton exec "bin/librecat copy -v main --bag project to search --bag project"
    echo "research_group."
    carton exec "bin/librecat copy -v main --bag research_group to search --bag research_group"
    echo "Done"
}

function f_export {
    echo "Exporting index..."

    mkdir -p ${TMPDIR}

    echo "user..."
    carton exec "bin/librecat user list" > ${TMPDIR}/user.yml
    echo "publication..."
    carton exec "bin/librecat publication list" > ${TMPDIR}/publications.yml
    echo "department..."
    carton exec "bin/librecat department list" > ${TMPDIR}/department.yml
    echo "project..."
    carton exec "bin/librecat project list" > ${TMPDIR}/project.yml
    echo "research_group..."
    carton exec "bin/librecat research_group list" > ${TMPDIR}/research_group.yml

    cd ${TMPDIR}

    OUTFILE=/tmp/librecat-index-export.$$.zip
    zip ${OUTFILE}  *

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
    carton exec "bin/librecat user add" ${TMPDIR}/user.yml
    echo "publications..."
    carton exec "bin/librecat publication add" ${TMPDIR}/publications.yml
    echo "department..."
    carton exec "bin/librecat department add" ${TMPDIR}/department.yml
    echo "project..."
    carton exec "bin/librecat project add" ${TMPDIR}/project.yml
    echo "research_group..."
    carton exec "bin/librecat research_group add" ${TMPDIR}/research_group.yml

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

case "${CMD}" in
    create)
        f_create
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
        confirm "Drop metrics data? [y/N]" && f_drop_metrics
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
        echo "usage: $0 {create|reindex|drop|drop_backup|drop_version|drop_all|export|import}"
        exit 1
esac
