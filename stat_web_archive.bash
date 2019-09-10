#!/bin/bash

###########################################################
# Build Deb
declare -a RELEASES=(xenial artful bionic cosmic disco)
AD_INT_PN=eagle-$C_VER
###########################################################

FULL_PACKAGE_NAME="$PACKAGE_NAME-$C_VER"

mkdir -p dists

for release in "${RELEASES[@]}"; do
	PKG_LOC=dists/$release/$FULL_PACKAGE_NAME
	mkdir -p $PKG_LOC
	ln --symbolic --relative "./dl_files/$AD_INT_PN" "$PKG_LOC/$AD_INT_PN"
done

