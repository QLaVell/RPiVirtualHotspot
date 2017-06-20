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
apt update && apt upgrade -y
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
cp ./dnsmasq.config $dnsmasq

# Prompt for new SSID and password for virtual hotspot
read -p 'Please enter a SSID for your virtual hotspot: ' ssid
read -sp 'Please enter a password for you virtual hotspot: ' password

# If the hostapd configuration file exists, make a copy
if [ -e $hostapd ]
then
  cp $hostapd ${hostapd}.orig
fi

# Create and edit the hostapd configuration file
echo interface=uap0 > $hostapd
echo ssid=$ssid >> $hostapd
echo hw_mode=g >> $hostapd
echo channel=6 >> $hostapd
echo macaddr_acl=0 >> $hostapd
echo auth_algs=1 >> $hostapd
echo ignore_broadcast_ssid=0 >> $hostapd
echo wpa=2 >> $hostapd
echo wpa_passphrase=$password >> $hostapd
echo wpa_key_mgmt=WPA-PSK >> $hostapd
echo wpa_pairwise=TKIP >> $hostapd
echo wpa_pairwise-CCMP >> $hostapd

# If the interfaces file backup exists, make a secondary copy, otherwise make a backup
if [ -e ${interfaces}.oirg ]
then
  cp $interfaces ${interfaces}.orig2
else
  cp $interfaces ${interfaces}.orig
fi

# insert a new line into the interfaces file and edit it
sed -n '/uap0/,/^$/!p' $interfaces > $interfaces
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
echo iptables -A FORWARD -i wlan0 -o uap0 -m state RELATED,ESTABLISHED -j ACCEPT >> $hostapdstart
echo iptables -A FORWARD -i uap0 -o wlan0 -j ACCEPT >> $hostapdstart
echo ifup uap0 >> $hostapdstart
echo service dnsmasq restart >> $hostapdstart
echo hostapd $hostapd >> $hostapdstart

# edit the permissions to allow all to execute
chmod 667 "$hostapdstart"

# make a copy of rc.local
if [ -e $rclocal ]
then
  cp $rclocal ${rclocal}.orig
fi

grep -Ev "exit|hostapdstart" $rclocal > $rc.local
echo >> $rclocal
echo hostapdstart >1& >> $rclocal
echo  >> $rclocal
echo exit 0 >> $rclocal

echo "System reboot required. Would you like to reboot now?"
select yn in "Yes" "No"; do
  case $yn in
    Yes ) reboot; break;;
    No ) exit;;
  esac
done 
