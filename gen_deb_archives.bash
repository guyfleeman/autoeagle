#!/bin/bash

###########################################################
# Meta/Maint
#
AUTHOR_NAME='William Stuckey'
AUTHOR_EMAIL='wstuckey3@gatech.edu'

LICENSE_NAME="Autodesk Terms of Use"
LICENSE="$(pwd)/meta/AUTODESK_LICENSE_INFO.TXT"
BIN_CACHE_DIR=./dl_files
PKG_CACHE_DIR=./pkg_files
PKG_CACHE_STAGING_DIR=$PKG_CACHE_DIR/staging
PATCH_INST=./patches
PATCH_DATA=./patch_data
#
#
# archive info
MAINTAINER_NAME='William Stuckey'
MAINTAINER_EMAIL='wstuckey3@gatech.edu'
PKG_NAME='autodesk-eagle-redist'
PKG_INST_PREFIX='opt'
ARCH='x64'
TYPE='INDEP'
###########################################################

if [ ! -f "$LICENSE" ]; then
	echo "WARNING: please fix AD license/legal info link"
	exit 1
fi

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
create_dir_or_quit $PKG_CACHE_STAGING_DIR "pacakge cache staging"
create_dir_or_quit $PATCH_INST "patch instructions cache"
create_dir_or_quit $PATCH_DATA "patch data cache"

echo "cache init complete."
echo ""

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
echo ""

###########################################################
# package generation
###########################################################

for v in "${GEN_VERSIONS[@]}"; do
	VER_PKG_NAME=${PKG_NAME}-${v}
	STAGING_DIR=${PKG_CACHE_STAGING_DIR}/${VER_PKG_NAME}
	STAGED_BIN_FLAG=${STAGING_DIR}/eagle
	DEB_STAGED_BIN_DIR=${STAGING_DIR}/debian

	EAGLE_DIR="eagle-$v"
	if [ ! -d "$STAGING_DIR" ]; then
		echo "staging $v in $STAGING_DIR"
		mkdir -p "$STAGING_DIR"
		if [ $? -ne 0 ]; then
			echo "could not create staging dir for $v"
			exit 1
		fi
	fi

	if [ ! -f "$STAGED_BIN_FLAG" ]; then
		echo "copying eagle-$v to $STAGING_DIR"
		cp -rp $BIN_CACHE_DIR/$EAGLE_DIR/* $STAGING_DIR/
		if [ $? -ne 0 ]; then
			echo "could not copy files to staging dir $STAGING_DIR"
			exit 1
		fi
	fi

	if [ ! -d "$DEB_STAGED_BIN_DIR" ]; then
		echo "no debian control for $v"
		echo "creating..."
	
		CUR_DIR=`pwd`
		cd "$STAGING_DIR" || exit
	
		export DEBEMAIL=$MAINTAINER_EMAIL
		export DEBFULLNAME=$MAINTAINER_NAME
		echo "running dh_make. It may take a few moments to create the compressed archive."
		dh_make --copyright custom --copyrightfile $LICENSE --indep --createorig --yes
		echo "done."
		res="$?"

		cd "$CUR_DIR" || exit

		if [ $res -ne 0 ]; then
			echo "failed to create debian staging control files for $v"
			exit 1
		else
			echo "created debain staging control files for $v"
		fi
	else
		echo "debian staging already compelete for $v"
	fi

	if [ ! -f $DEB_STAGED_BIN_DIR/install ]; then
		echo "no install file in debian control"

		echo "will build recursively..."
		CUR_DIR=$(pwd)
		cd $PKG_CACHE_STAGING_DIR || exit
		# shellcheck disable=SC2086
		ALL_FILES=$(find $VER_PKG_NAME -type f)
		if [ $? -ne 0 ]; then
			echo "failed to enumerate files"
			exit 1
		fi

		# load all files into an array for patching, override IFS to skip spaces
		# ths fucking examples directory has folders with spaces, so we gotta handle that
		declare -a all_files_arr
		IFS=$'\n' read -d '' -r -a all_files_arr <<< $ALL_FILES

    # stripping TLDs
    echo "fixing TLDs"
		for i in "${!all_files_arr[@]}"; do
			all_files_arr[$i]="$(echo "${all_files_arr[$i]}" | sed -e "s/$VER_PKG_NAME\///g")"
		done

    # patching spaces
    echo "fixing illegal folders for debian install"
		for i in "${!all_files_arr[@]}"; do
			all_files_arr[$i]="$(echo "${all_files_arr[$i]}" | sed -e "s/ /?/g")"
		done

    echo "remove meta/control files"
    declare -a install_files_arr
		for patched_fn in "${all_files_arr[@]}"; do
		  if [[ $patched_fn != "debian"* ]]; then
		    install_files_arr+=("$patched_fn")
		  fi
		done

    echo "install files:"
		for patched_fn in "${install_files_arr[@]}"; do
			echo -e "\t$patched_fn"
		done

    echo "building debian install entries"
    declare -a deb_inst_entries
		for patched_fn in "${install_files_arr[@]}"; do
		  inst_loc=$PKG_INST_PREFIX/$VER_PKG_NAME/$(dirname "$patched_fn")
			install_ent="$patched_fn  $inst_loc"
			echo -e "\t$install_ent"
			deb_inst_entries+=("$install_ent")
		done

		DEB_INSTALL_FILE=${VER_PKG_NAME}/debian/install
		touch "$DEB_INSTALL_FILE"
		if [ $? -ne 0 ]; then
			echo "failed to create install manifest file"
			exit 1
		fi

		#find $VER_PKG_NAME -type f | grep -xv "$VER_PKG_NAME" | sed -e "s/$VER_PKG_NAME\///g" | grep -v "debian" | sed -r "s/ /?/g" | sed "s/\$/  $PKG_INST_PREFIX\/$VER_PKG_NAME/" > ${VER_PKG_NAME}/debian/install

		echo "clearing install file"
		echo "" > "$DEB_INSTALL_FILE"
		for inst_ent in "${deb_inst_entries[@]}"; do
		  echo "$inst_ent" >> "$DEB_INSTALL_FILE"
		done

		#if [ $? -ne 0 ]; then
		#	echo "failed to generate the install manifest"
		#	exit 1
		#else
		#	echo "created the install manifest in debian control"
		#fi

		cd "$VER_PKG_NAME" || exit
		echo "gen deb"
		debuild -us -uc

		if [ $? -ne 0 ]; then
			echo "failed to generate deb file"
			rm "debian/install"
		fi

    unset all_files_arr
    unset install_files_arr
    unset deb_inst_entries

		cd "$CUR_DIR" || exit
	fi

	#INST_DIR=${PKG_INST_PREFIX}/${PKG_NAME}

	echo ""
done



