#!/bin/bash

echo "Killing any current apt upgrades"
systemctl stop apt-daily-upgrade.service
echo ""

timestamp=`date '+%Y%m%d%H%M'`;
logdir="$PWD/log/$timestamp"
logfile_install="$logdir/installation.log"
logfile_systemd_analyze="$logdir/systemd_startup.svg"
logzip="$logdir/logs.zip"

echo "Starting installation"
echo ""

mkdir -p $logdir
./install_server.sh |& tee $logfile_install
systemd-analyze plot > $logfile_systemd_analyze

echo "Generating $logzip. Include it when asking questions"
source ~/.profile
zip $logzip $logfile_install $logfile_systemd_analyze
echo ""

