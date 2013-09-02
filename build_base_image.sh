#!/bin/bash
# Build the OMERO base VirtualBox image using Veewee.
# Example: ./build_base_image.sh Debian-7.1.0-amd64-omerobase

set -e -x

if [ $# -ne 1 ]; then
	echo Usage: `basename $0` base_definition_name
	exit 1
fi

if [ -d "$HOME/VirtualBox VMs/" ]; then
	VBOXVMS="$HOME/VirtualBox VMs/"
else
	echo "Cannot find VirtualBox VMs directory"
	exit 2
fi

BASEBOX=$1
BUILD_NUMBER=${BUILD_NUMBER:-DEV}
KEEP_VM=0

# Veewee/VirtualBox sometimes exits before releasing the underlying files
# which can cause locking issues or file corruption. This is an attempt to
# work around it.
wait_for_vbox()
{
    if [ ! -f "$1" ]; then
        echo "ERROR: Invalid file"
        exit 2
    fi
    RET=0
    set +e
    echo -n "Waiting for VBox to release file "
    while [ $RET -eq 0 ]; do
        echo -n .
        sleep 5
        lsof -Fc "$1" |grep VBoxHeadless
        RET=$?
    done
    echo
    set -e
}

# Setup the Ruby environment
. ~/.rvm/scripts/rvm
rvm use 1.9.2
# Install Ruby Gem dependencies if not already present
bundle install

# Build the box
bundle exec veewee vbox build --force "$BASEBOX" --nogui
bundle exec veewee vbox halt "$BASEBOX"

# At this point there should be a new VirtualBox machine in the VirtualBox
# directory, for example under
# `~/VirtualBox VMs/Debian-7.1.0-amd64-omerobase/`.
#
# If you want to keep the base VM then clone the VDI to another directory,
# do not just copy the VDI since it contains a UUID registered to the base
# image VM.  Note the VDI will remain registered to VirtualBox as a hard disk.
#
# Alternatively copy the VDI and delete the original VM

SOURCE="$VBOXVMS/${BASEBOX}/${BASEBOX}.vdi"
DEST="$PWD/${BASEBOX}-b${BUILD_NUMBER}.vdi"

wait_for_vbox "$SOURCE"

if [ $KEEP_VM -eq 0 ]; then
	cp "$SOURCE" "$DEST"
	bundle exec veewee vbox destroy "$BASEBOX"
else
	VBoxManage clonehd "$SOURCE" "$DEST"
fi

echo "Base image: $DEST"

