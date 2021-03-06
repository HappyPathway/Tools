#!/bin/bash
# set -e

CONFIG_FILE=$BUILD_DIR/$1
APP_NAME=$2

# SHORT_HASH=$(echo $TRAVIS_COMMIT | cut -c1-8)
# echo $SHORT_HASH

if [ -z $CONFIG_FILE ]
then
  echo "No Config File Specified"
  exit 1
fi

if [ -z $APP_NAME ]
then
  echo "No App Name Specified"
  exit 1
fi



echo "Using $CONFIG_FILE to build $APP_NAME"
REPO_URL=$(cat $CONFIG_FILE | jq -r .repoUrl)
echo Repo: $REPO_URL

PACKAGE_NAME=$(cat $CONFIG_FILE | jq -r .packageName)
echo Package: $PACKAGE_NAME

VERSION=$(cat $CONFIG_FILE | jq -r .packageVersion)
echo Version: $VERSION

PACKAGE_URL=$REPO_URL/$PACKAGE_NAME
echo Package url: $PACKAGE_URL


# setup functions
functions=$(dirname $0)/functions.sh
echo $functions
source $functions

echo "Working on Branch: ${BRANCH}"
if [ -z "${BRANCH}"]
  then 
    PACKAGE_APP_NAME=$APP_NAME
  else
    if [ "${BRANCH}" != "master" ]
      then
        PACKAGE_APP_NAME=$APP_NAME-$BRANCH
      else
        PACKAGE_APP_NAME=$APP_NAME
    fi
fi


# standard deb package prep
init_tmp

# download package if need be
if [ $(needs_download) -ne "0" ]
  then
    download_pkg
    pre_extract_commands
    if [ $(is_zip) -ne "0" ]
      then
        unpack
        extract_data
        extract_control
      else
        rm -rf zip_data/*
        unpack_zip
    fi
fi

# if you need to run various commands for cleaning, creating files/dirs
# or other types of commands, this is where you'd run them
pre_config_commands

has_configs=$( jq -r ".configs | length " < $CONFIG_FILE )
echo "This app has configs: $has_configs"
if [ $( jq -r ".configs | length " < $CONFIG_FILE ) > 0 ]
then
    cp_configs $CONFIG_FILE $APP_NAME
fi

cd ..

echo "repacking debian package"

# BRANCH_NAME=$(git branch | grep \* | cut -d ' ' -f2)

FPM_CMD="fpm -s dir -t deb -n ${PACKAGE_APP_NAME} -v ${VERSION}"

pre_install
if [ -f preinst ]
then
  FPM_CMD=$FPM_CMD" --before-install preinst"
fi

post_install
if [ -f postinst ]
then
  FPM_CMD=$FPM_CMD" --after-install postinst "
fi

post_remove
if [ -f prerm ]
then
  FPM_CMD=$FPM_CMD" --after-remove prerm"
fi
if [ -f postrm ]
then
  FPM_CMD=$FPM_CMD" --after-remove postrm"
fi

script_name=$(upstart_script)
if [ -n "$script_name" ]
then
  FPM_CMD=$FPM_CMD" --deb-upstart $script_name"
fi


if [ $( jq -r ".pre_dependencies | length " < $CONFIG_FILE ) > 0 ]
  then
    FPM_CMD=$FPM_CMD" $(pkg_pre_dependencies $CONFIG_FILE $APP_NAME) "
fi

if [ $( jq -r ".dependencies | length " < $CONFIG_FILE ) > 0 ]
  then
    FPM_CMD=$FPM_CMD" $(pkg_dependencies $CONFIG_FILE $APP_NAME) "
fi


if [ $(is_zip) -ne "0" ]
then
  FPM_CMD=$FPM_CMD" -a amd64 tmp/data/=/"
else
  FPM_CMD=$FPM_CMD" -a amd64 tmp/zip_data/=/"
fi


echo $FPM_CMD
rm $PACKAGE_APP_NAME*.deb || echo "no deb $APP_NAME package in $(pwd)"
eval $FPM_CMD

if [ ! -z "${APT_REPO_DIR}"]
  then
    rm ${APT_REPO_DIR}/*.deb || echo "no deb packages in build/*.deb"
    mkdir ${APT_REPO_DIR} || echo "build directory already created"
    mv *.deb ${APT_REPO_DIR}
fi

cleanup;