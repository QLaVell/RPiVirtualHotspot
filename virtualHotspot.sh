#!/bin/bash

# virtualHotspot - Creates necessary files to launch a virtual hotspot on a raspberry pi 3B or newer.

# Necessary files for editing
dnsmasq="/etc/dnsmasq.conf"
hostapd="/etc/hostapd/hostapd.conf"
interfaces="/etc/network/interfaces"
hostapdstart="/usr/local/bin/hostapdstart"
rclocal="/etc/rc.local"

# Check if script was run as root, quit if not
if [[ $EUID -ne 0 ]]
  then echo "This script must be run as root"
  exit
fi

# update and upgrade the system to prepare for installation
#apt update && apt upgrade -y
# install necessary packages
apt install hostapd dnsmasq -y

# If a copy of the dnsmasq config file already exists, move it to a secondary backup, otherwise back up
# the original
if [ -e ${dnsmasq}.orig ]
then 
  cp $dnsmasq ${dnsmasq}.orig2
else
  cp $dnsmasq ${dnsmasq}.orig
fi

# Copy included dnsmasq configuration file
cp ./dnsmasq.conf $dnsmasq

# Prompt for new SSID and password for virtual hotspot
custom=false
if [ "$custom" = true ]
then
  read -p 'Please enter a SSID for your virtual hotspot: ' ssid
  read -sp 'Please enter a password for you virtual hotspot (must be 8 characters or more): ' password
  passwdlen=${#password}
  while [ $passwdlen -lt 8 ]
  do
    echo
    read -sp 'The password you entered was too short. Please enter a password of 8 or more characters: ' password
    passwdlen=${#password}
  done
else
  ssid="RPi"$(awk -F ':' '{print $(NF-1) $(NF)}' /sys/class/net/wlan0/address)
  password="iRobot123"
fi

# Get channel of connected wifi
channel=$(iwgetid --channel -r)
if [ -z "$channel" ]
then
  channel=6
fi

# If the hostapd configuration file exists, make a copy
if [ -e $hostapd ]
then
  cp $hostapd ${hostapd}.orig
fi

# Create and edit the hostapd configuration file
echo interface=uap0 > $hostapd
echo ssid=$ssid >> $hostapd
echo hw_mode=g >> $hostapd
echo channel=$channel >> $hostapd
echo macaddr_acl=0 >> $hostapd
echo auth_algs=1 >> $hostapd
echo ignore_broadcast_ssid=0 >> $hostapd
echo wpa=2 >> $hostapd
echo wpa_passphrase=$password >> $hostapd
echo wpa_key_mgmt=WPA-PSK >> $hostapd
echo wpa_pairwise=TKIP >> $hostapd
echo wpa_pairwise=CCMP >> $hostapd

# If the interfaces file backup exists, make a secondary copy, otherwise make a backup
if [ -e ${interfaces}.oirg ]
then
  cp $interfaces ${interfaces}.orig2
else
  cp $interfaces ${interfaces}.orig
fi

# insert a new line into the interfaces file and edit it
touch ${interfaces}.temp
chmod a+w ${interfaces}.temp
sed -n '/uap0/,/^$/!p' $interfaces > ${interfaces}.temp
mv ${interfaces}.temp $interfaces
echo auto uap0 >> $interfaces
echo iface uap0 inet static >> $interfaces
echo address 172.24.1.1 >> $interfaces
echo netmask 255.255.255.0 >> $interfaces
echo network 172.24.1.0 >> $interfaces
echo broadcast 172.24.1.255 >> $interfaces

# If the hostapdstart script exists, make a backup
if [ -e $hostapdstart ]
then
  cp $hostapdstart ${hostapdstart}.orig
fi

# Create and edit the hostapdstart script
echo iw dev wlan0 interface add uap0 type __ap > $hostapdstart
echo sysctl net.ipv4.ip_forward=1 >> $hostapdstart
echo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE >> $hostapdstart
echo iptables -A FORWARD -i wlan0 -o uap0 -m state --state RELATED,ESTABLISHED -j ACCEPT >> $hostapdstart
echo iptables -A FORWARD -i uap0 -o wlan0 -j ACCEPT >> $hostapdstart
echo ifup uap0 >> $hostapdstart
echo service dnsmasq restart >> $hostapdstart
echo hostapd $hostapd >> $hostapdstart

# edit the permissions to allow all to execute
chmod 667 "$hostapdstart"

automated=true
if [ "$automated"=false ]
then
  # make a copy of rc.local
  if [ -e $rclocal ]
  then
    cp $rclocal ${rclocal}.orig
  fi

  grep -Ev "exit|hostapdstart" $rclocal > ${rclocal}.temp
  mv ${rclocal}.temp $rclocal
  echo >> $rclocal
  echo "hostapdstart >1&" >> $rclocal
  echo  >> $rclocal
  echo exit 0 >> $rclocal

  chmod 755 $rclocal

  echo
  echo "System reboot required. Would you like to reboot now?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes ) reboot; break;;
      No ) exit;;
    esac
  done
fi
