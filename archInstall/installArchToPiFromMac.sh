#!/bin/bash

# stop on any errors
set -e

# ensure root
if (( `id -u` != 0 )); then
  echo Please run with sudo
  exit 1
fi

function usage() {
cat <<EOF
setupArchOnPi: will install and configure arch linux on a raspberry pi
Usage: $(basename "$0") [switches] [--]
      -f archImage    Location of the arch linux image .iso
      -h                 This help
Hint: if you see end of file without any output, make sure you can ssh without problems
EOF
}

# leading ':' to run silent, 'f:' means f need an argument, 'c' is just an option
while getopts ":f:h" opt; do case $opt in
	h)  usage; exit 0;;
	f)  if [[ ! -e "$OPTARG" ]]; then usage; echo "\$OPTARG" does not exist for -f; exit 1; fi
	    isoFile="$OPTARG";;
	\?) usage; echo "Invalid option: -$OPTARG" >&2; exit 1;;
        # this happens when silent and missing argument for option
	:)  usage; echo "-$OPTARG requires an argument" >&2; exit 1;;
	*)  usage; echo "Unimplemented option: -$OPTARG" >&2; exit 1;; # catch-all
esac; done

if [[ -z "${isoFile}" ]]; then echo "You much specify an iso file with -f"; exit 1; fi

# isoFile gets passed to the script as first argument, script is sourced remotely
sh <(curl -fsSL https://raw.github.com/plockc/DevOps/master/archInstall/imageInstallToSDCard.sh) $isoFile

echo Just eject the SD card and install to Raspberry Pi and power the Pi on, then hit enter to continue

ssh alarpi echo done!

# bash <(curl -fsSL https://raw.github.com/plockc/ArchDevOps/master/archInstall/archPiPostInstall.sh)