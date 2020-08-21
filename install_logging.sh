#!/bin/bash

timestamp=`date '+%Y%m%d%H%M'`;
logdir="$PWD/log/$timestamp"
logfile="$logdir/installation.log"
logzip="$logdir/logs.zip"

echo "Starting installation"
echo ""

mkdir -p $logdir
./install_server.sh |& tee $logfile

echo "Generating $logzip. Include it when asking questions"
zip $logzip $logfile
echo ""

