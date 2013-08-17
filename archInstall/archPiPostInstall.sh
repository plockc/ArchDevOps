#!/bin/bash

# USAGE: (run on the pi)
# bash <(curl -fsSL https://raw.github.com/plockc/ArchDevOps/master/archInstall/archPiPostInstall.sh)

# TODO: request for hostname and for a initial password

set -e

if (( `id -u` != 0 )); then
  echo Please run with sudo
  exit 1
fi

pacman --noconfirm -Sy --needed php augeas darkstat unzip dnsutils rsync screen
ln -s /usr/bin/darkstat /usr/sbin/darkstat

# CHANGE PASSWORD IF STILL THE DEFAULT "ROOT"
salt=`grep root /etc/shadow | sed 's/root:\(\$.*\$.*\)\$.*/\1/'`
defaultPass=`php -r "echo crypt('root', \"${salt//\$/\\\\\\$}\");"`
if grep -q "${defaultPass//\$/\\\$}" /etc/shadow; then
read -s -p "Please enter a new root password: "
NEW_PASSWORD=$REPLY
echo
read -s -p "Please confirm: "
echo

if [[ ! $REPLY == $NEW_PASSWORD ]]; then
  echo Passwords did not match, please try again
  exit
fi
chpasswd << EOSF
root:$NEW_PASSWORD
EOSF
fi

# UPDATE HOSTNAME
if grep alarmpi <<< `hostname`; then
  read -p "Please enter the full host name for this Pi: "
  HOSTNAME=$REPLY
  if [[ $HOSTNAME == "" ]]
  then
    echo Please try again with a valid host name
    exit;
  fi
  echo $HOSTNAME > /etc/hostname
fi

# SETUP TIMEZONE
ln --force -s /usr/share/zoneinfo/US/Pacific /etc/localtime

# SETUP SERVICES
systemctl enable dhcpcd@eth0 darkstat

# RESIZE THE FILESYSTEM TO MATCH PARTITION SIZE
resize2fs /dev/mmcblk0p2

echo
echo Rebooting, please wait about 25 seconds before \"ssh "root@$HOSTNAME"\"

reboot #25 seconds to reboot

