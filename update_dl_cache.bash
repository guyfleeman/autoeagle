#!/bin/bash

###########################################################
# Meta/Maint
#
AUTHOR_NAME='William Stuckey'
AUTHOR_EMAIL='wstuckey3@gatech.edu'

BIN_CACHE_DIR=./dl_files
EAGLE_DL_URL=https://www.autodesk.com/eagle-download-lin
###########################################################

###########################################################
# Support Functions
###########################################################

containsElement () {
	local e match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && return 0; done

	return 1
}

tmp_dir_created=false
clean_and_exit () {
	if [ "$tmp_dir_created" = true ]; then
		echo "deleting $TMP_DIR"
		rm -rf $TMP_DIR
	fi

	echo "quitting..."
	exit $1
}


###########################################################
# Setup
###########################################################

mkdir -p $BIN_CACHE_DIR

# make the working space
TMP_DIR=`mktemp -d`
if [ $? -ne 0 ]; then
	echo "Failed make to tmp FS for build"
	exit 1
else
	tmp_dir_created=true
	echo "Created working space: $TMP_DIR"
fi

# get locally cached eagle versions
declare -a KNOWN_VERSIONS
for entry in "$BIN_CACHE_DIR"/*; do
	KNOWN_VER=`echo $entry | grep -iEo "[0-9]*\.[0-9]*\.[0-9]*"`
	if [ $? -ne 0 ]; then
		continue
	fi

	KNOWN_VERSIONS+=($KNOWN_VER)
done

echo "CACHED_EAGLE_VERSIONS ${KNOWN_VERSIONS[@]}"


###########################################################
# Autodesk File Acquisition, and Verison Check
###########################################################

wget --directory-prefix $TMP_DIR --content-disposition $EAGLE_DL_URL
if [ $? -ne 0 ]; then
	echo "Failed to fetch the eagle file"
	clean_and_exit 1
fi

found=0
for entry in "$TMP_DIR"/*; do
	C_FN=$entry
	C_VER=`echo $entry | grep -iEo "[0-9]*\.[0-9]*\.[0-9]*"`
	if [ $? -ne 0 ]; then
		continue
	fi

	found=1
	break
done

if [ $found -eq 0 ]; then
	echo "Could not extract a version from the fetched file"
	clean_and_exit 1
else
	echo "LATEST_VERSION $C_VER"
	echo "The latest version of Autodesk Eagle is $C_VER"
fi

containsElement "$C_VER" "${KNOWN_VERSIONS[@]}"
if [ $? -eq 0 ]; then
	echo "Version already archived"
	echo "Nothing to do."
	clean_and_exit 0
fi

echo "Extracting $C_VER..."
tar -xf $C_FN -C $RAW_DL_CACHE

if [ $? -ne 0 ]; then
	echo "failed to extract the archive"
	clean_and_exit 1
fi


