#!/bin/bash

## Optionally provide a directory where to store the Dancer
## temporary files
# export TMPDIR=/data2/tmp

if [ "$1" == "starman" ]; then
    carton exec 'plackup -R lib -s Starman --port 5001  bin/app.pl'
else
    carton exec 'plackup -R lib --port 5001  bin/app.pl'
fi
