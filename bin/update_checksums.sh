#!/bin/bash
#
# Example crontab script to update the checksums for installations
# which use the Simple storage backend and still want to support
# md5 checksums. Hint: a better choice would be to migrate to the
# BagIt backend which has automatic MD5 checksum support

LOGFILE=logs/update_checksum.log

YESTERDAY=$(date --date yesterday --utc +%Y-%m-%dT%H:%M:%SZ)

NOW=$(date --utc +%Y-%m-%dT%H:%M:%SZ)
echo "${NOW} start" >> ${LOGFILE}
bin/librecat export search \
        --bag publication \
        --q "(file_date_updated > ${YESTERDAY})" \
        to TSV --header 0 --fix 'retain(_id)' > /tmp/update_checksum.$$

bin/librecat publication checksum init /tmp/update_checksum.$$ >> ${LOGFILE}

rm /tmp/update_checksum.$$

NOW=$(date --utc +%Y-%m-%dT%H:%M:%SZ)
echo "${NOW} end" >> ${LOGFILE}
