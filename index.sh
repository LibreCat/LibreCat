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
	echo "researcher..."
	carton exec catmandu delete search --bag researcher
	echo "publication..."
	carton exec catmandu delete search --bag publication
	echo "department..."
	carton exec catmandu delete search --bag department
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

	rm -rf ${TMPDIR}

	echo "Done"
    ;;
   *)
	echo "usage: $0 {create|drop|export|import}"
	exit 1
esac
