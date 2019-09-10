#!/bin/bash

###########################################################
# Meta/Maint
#
AUTHOR_NAME='William Stuckey'
AUTHOR_EMAIL='wstuckey3@gatech.edu'

BIN_CACHE_DIR=./dl_files
PKG_CACHE_DIR=./pkg_files
PATCH_INST=./patches
PATCH_DATA=./patch_data
#
#
# archive info
MAINTAINER_NAME='William Stuckey'
MAINTAINER_EMAIL='wstuckey3@gatech.edu'
ARCH='x64'
TYPE='INDEP'
###########################################################

if [ ! -d $BIN_CACHE_DIR ]; then
	echo "binary cache location does not exist"
	echo 1
else
	echo "located binary cache at $BIN_CACHE_DIR"
fi

create_dir_or_quit () {
	DIR="$1"
	NAME="$2"

	if [ ! -d $DIR ]; then
		echo "$NAME does not exist"

		echo "creating $NAME..."
		mkdir -p $DIR
		if [ $? -ne 0 ]; then
			echo "failed."
			exit 1
		else
			echo "done."
		fi
	else
		echo "located $NAME at $DIR"
	fi
}

create_dir_or_quit $PKG_CACHE_DIR "package cache"
create_dir_or_quit $PATCH_INST "patch instructions cache"
create_dir_or_quit $PATCH_DATA "patch data cache"

###########################################################
# enumerate versions + calc packaging work
###########################################################

# get bin package versions
declare -a BIN_PKG_VERSIONS
for entry in "$BIN_CACHE_DIR"/*; do
	KNOWN_BIN_V=`echo $entry | grep -iEo "[0-9]*\.[0-9]*\.[0-9]*"`
	if [ $? -ne 0 ]; then
		echo "non-comliant entry in bin cache: $entry"
		continue
	fi

	BIN_PKG_VERSIONS+=($KNOWN_BIN_V)
done

echo "BINARY_VERSIONS ${BIN_PKG_VERSIONS[@]}"


# get deb package versions
declare -a DEB_PKG_VERSIONS
for entry in "$BIN_CACHE_DIR"/*; do
	KNOWN_DEB_V=`echo $entry | grep -iEo "[0-9]*\.[0-9]*\.[0-9]*"`
	if [ $? -ne 0 ]; then
		echo "non-comliant entry in bin cache: $entry"
		continue
	fi

	BIN_DEB_VERSIONS+=($KNOWN_DEB_V)
done

echo "DEBIAN_PACKAGE_VERSIONS ${DEB_PKG_VERSIONS[@]}"

function contains_el () {
	local e match="$1"
	shift
	for e; do [[ "$s" == "$match" ]] && return 0; done

	return 1
}

# calculate the diff
declare -a GEN_VERSIONS
for bin_v in "${BIN_PKG_VERSIONS[@]}"; do
	contains_el "$bin_v" "${DEB_PKG_VERSIONS[@]}"
	if [ $? -eq 0 ]; then
		continue
	fi

	GEN_VERSIONS+=($bin_v)
done

NUM_DEB_TO_GEN=${#GEN_VERSIONS[@]}
if [ "$NUM_DEB_TO_GEN" = "0" ]; then
	echo "no debian archives to generate..."
	echo "quitting."
	exit 0
fi

echo "will generate $NUM_DEB_TO_GEN packages..."
echo "create versions ${GEN_VERSIONS[@]} ..."

###########################################################
# package generation
###########################################################
