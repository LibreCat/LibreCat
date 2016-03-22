#!/bin/bash

TMPDIR=/tmp/librecat-$$
CMD=$1

case "${CMD}" in
   create)
	echo "Creating index..."
	carton exec catmandu import YAML to search --bag researcher < devel/researcher.yml
	carton exec catmandu import YAML to search --bag publication < devel/publications.yml
	carton exec catmandu import YAML to search --bag department < devel/department.yml
	echo "Done"
	;;
   drop)
	echo "Dropping index.."
	carton exec catmandu delete search --bag researcher
	carton exec catmandu delete search --bag publications
	carton exec catmandu delete search --bag department
	echo "Done"
	;;
   export)
	echo "Exporting index..."

	mkdir -p ${TMPDIR}

	carton exec catmandu export search --bag researcher  to YAML > ${TMPDIR}/researcher.yml
	carton exec catmandu export search --bag publication to YAML > ${TMPDIR}/publications.yml
	carton exec catmandu export search --bag department to YAML > ${TMPDIR}/department.yml

	cd ${TMPDIR}

	OUTFILE=/tmp/librecat-index-export.$$.zip
	zip ${OUTFILE}  *

	cd -

	rm -rf ${TMPDIR}

	echo "Output ready in: ${OUTFILE}"
	echo "Done"
	;;
   import)
    FILE=$2

    if [ "${FILE}" == "" ]; then
    	echo "Need a zipfile"
    	echo "usage: $0 index zipfile"
    	exit 1
    fi

    ;;
   *)
	echo "usage: $0 {create|drop|export|import}"
	exit 1
esac
