#!/bin/bash

TMPDIR=/tmp/librecat-$$
CMD=$1

case "${CMD}" in
    create)
        echo "Creating index..."
        echo "researcher..."
        carton exec catmandu import YAML to search --bag researcher < devel/researcher.yml
        echo "publication..."
        carton exec catmandu import YAML to search --bag publication < devel/publications.yml
        echo "department..."
        carton exec catmandu import YAML to search --bag department < devel/department.yml
        echo "project..."
        carton exec catmandu import YAML to search --bag project < devel/project.yml
        echo "Done"
        ;;
    drop)
        echo "Dropping index.."
        echo "researcher..."
        carton exec catmandu delete search --bag researcher
        echo "publication..."
        carton exec catmandu delete search --bag publication
        echo "department..."
        carton exec catmandu delete search --bag department
        echo "research_group..."
        carton exec catmandu delete search --bag research_group
        echo "project..."
        carton exec catmandu delete search --bag project
        echo "award..."
        carton exec catmandu delete search --bag award
        echo "Done"
        ;;
    drop_backup)
        echo "Dropping index.."
        echo "ids..."
        carton exec catmandu delete default --bag data
        echo "researcher..."
        carton exec catmandu delete default --bag researcher
        echo "publication..."
        carton exec catmandu delete default --bag publication
        echo "department..."
        carton exec catmandu delete default --bag department
        echo "project..."
        carton exec catmandu delete default --bag project
        echo "research_group..."
        carton exec catmandu delete default --bag research_group
        echo "award..."
        carton exec catmandu delete default --bag award
        echo "Done"
        ;;
    export)
        echo "Exporting index..."

        mkdir -p ${TMPDIR}

        echo "researcher..."
        carton exec catmandu export search --bag researcher  to YAML > ${TMPDIR}/researcher.yml
        echo "publication..."
        carton exec catmandu export search --bag publication to YAML > ${TMPDIR}/publications.yml
        echo "department..."
        carton exec catmandu export search --bag department to YAML > ${TMPDIR}/department.yml
        echo "project..."
        carton exec catmandu export search --bag project to YAML > ${TMPDIR}/project.yml
        echo "award..."
        carton exec catmandu export search --bag award to YAML > ${TMPDIR}/award.yml
        echo "research_group..."
        carton exec catmandu export search --bag research_group to YAML > ${TMPDIR}/research_group.yml

        cd ${TMPDIR}

        OUTFILE=/tmp/librecat-index-export.$$.zip
        zip ${OUTFILE}  *

        cd -

        rm -rf ${TMPDIR}

        echo "Output ready in: ${OUTFILE}"
        echo "Done"
        ;;
    import)
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

        echo "researcher..."
        carton exec catmandu import YAML to search --bag researcher < ${TMPDIR}/researcher.yml
        echo "publications..."
        carton exec catmandu import YAML to search --bag publication < ${TMPDIR}/publications.yml
        echo "department..."
        carton exec catmandu import YAML to search --bag department < ${TMPDIR}/department.yml
        echo "project..."
        carton exec catmandu import YAML to search --bag project < ${TMPDIR}/project.yml
        echo "award..."
        carton exec catmandu import YAML to search --bag project < ${TMPDIR}/award.yml
        echo "research_group..."
        carton exec catmandu import YAML to search --bag research_group < ${TMPDIR}/research_group.yml

        rm -rf ${TMPDIR}

        echo "Done"
        ;;
    *)
        echo "usage: $0 {create|drop|drop_backup|export|import}"
        exit 1
esac
