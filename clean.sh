#!/bin/bash

#Files needing edited/changed
dnsmasq="/etc/dnsmasq.conf"
hostapd="/etc/hostapd/hostapd.conf"
interfaces="/etc/network/interfaces"
hostapdstart="/usr/local/bin/hostapdstart"
rclocal="/etc/rc.local"

if [[ $EUID -ne 0 ]]
then
  echo "This script must be run as root"
  exit
fi

echo Cleaning previous run...

for FILE in $dnsmasq $interfaces $rclocal
do
  if [ -e ${FILE}.orig ]
  then
    cp ${FILE}.orig $FILE
  fi
done

for FILE in $hostapd $hostapdstart
do
  if [ -e ${FILE}.orig ]
  then
    cp ${FILE}.orig $FILE
  else
    rm $FILE
  fi
done

echo Finished cleaning!
