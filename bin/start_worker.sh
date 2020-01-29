#!/bin/bash

cd `dirname $0`/..

[ -f env.sh ] && . env.sh

bin/mojo_app.pl minion worker -m production

