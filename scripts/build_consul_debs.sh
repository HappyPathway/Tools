#!/bin/bash
# set -e

CONFIG_FILE=$TRAVIS_BUILD_DIR/$1
APP_NAME=$2

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

UPSTART_SCRIPT=$(cat $CONFIG_FILE | jq -r .upstart)
echo upstart: $UPSTART_SCRIPT

AFTER_INSTALL=$(cat $CONFIG_FILE | jq -r .after-install)
echo upstart: $AFTER_INSTALL

BINARY_NAME=$(cat $CONFIG_FILE | jq -r .binaryName)
echo executable name: $BINARY_NAME

echo "Working on Branch: $TRAVIS_BRANCH"
if [ "$TRAVIS_BRANCH" != "master" ]
then
  PACKAGE_APP_NAME=$APP_NAME-$TRAVIS_BRANCH
else
  PACKAGE_APP_NAME=$APP_NAME
fi

function unpack_consulzip {
	echo "Unpacking zipfile"

	mkdir zip_data
	unzip $PACKAGE_NAME -d zip_data/
}

function cp_configs {
   config=$1
   app_name=$2
   actual_array_size=$( jq -r ".configs | length " < $CONFIG_FILE )
   useable_array_size=$(echo $actual_array_size-1 | bc)
   for i in $(seq 0 $useable_array_size);
     do
       file_source=$(get_source $config $APP_NAME $i);
       destination=$(get_destination $config $APP_NAME $i)
       echo "$file_source -> $destination";
       if [ $(is_zip) -ne "0" ]
         then
           mkdir -p data/$destination;
           cp $(pwd)/../$file_source data/$destination/.;
         else
           mkdir -p ../zip_data/$destination;
           cp $(pwd)/../$file_source ../zip_data/$destination/.;
       fi
     done
}

function get_configs {
    config=$1
    app_name=$2
    actual_array_size=$( jq -r ".configs | length " < $CONFIG_FILE )
    useable_array_size=$(echo $actual_array_size-1 | bc)
    output=" "
    for i in $(seq 0 $useable_array_size);
    do
        file_source=$(get_source $config $APP_NAME $i);
        destination=$(get_destination $config $APP_NAME $i)
        output="${output} ../${file_source}=${destination}"
    done
    echo $output
}

function pkg_dependencies {
   config=$1
   app_name=$2
   actual_array_size=$( jq -r ".dependencies | length " < $CONFIG_FILE )
   useable_array_size=$(echo $actual_array_size-1 | bc)
   dependecies_flags=""
   if [ actual_array_size -ne 0 ]
     then
       for i in $(seq 0 $useable_array_size);
         do
           dependencies=$(jq -r .dependencies[$i] < $CONFIG_FILE)
           dependecies_flags="$dependecies_flags  --depends $dependencies "
         done
       echo $dependecies_flags
   fi
}

function get_source {
   config=$1
   app_name=$2
   index=$3
   echo  $(jq -r .configs[$index].source < $CONFIG_FILE)
}

function get_destination {
   config=$1
   app_name=$2
   index=$3
   echo  $(jq -r .configs[$index].destination < $CONFIG_FILE)
}

has_configs=$( jq -r ".configs | length " < $CONFIG_FILE )

# standard deb package prep
rm -rf tmp
mkdir tmp
cd tmp
wget $PACKAGE_URL
rm -rf zip_data/*
unpack_consulzip


mkdir build_root/

# if you need to run various commands for cleaning, creating files/dirs
# or other types of commands, this is where you'd run them
pre_config_commands



echo "repacking debian package"

FPM_CMD="fpm -s dir -t deb -n $APP_NAME -v $VERSION"


FPM_CMD=$FPM_CMD" $(pkg_dependencies $CONFIG_FILE $APP_NAME)"
if [ -n "$UPSTART_SCRIPT" -a "$UPSTART_SCRIPT" != "null" ]
then
    FPM_CMD="${FPM_CMD} --deb-upstart ../${UPSTART_SCRIPT}"
fi
FPM_CMD="${FPM_CMD} ./zip_data/${BINARY_NAME}=/usr/local/${BINARY_NAME}/${BINARY_NAME}"
if [ $has_configs > 0 ]
then
    FPM_CMD="${FPM_CMD} $(get_configs $CONFIG_FILE $PACKAGE_APP_NAME)"
fi
if [ -n "$AFTER_INSTALL" ]
then
    FPM_CMD="${FPM_CMD} --after-install ../${AFTER_INSTALL}"
fi



echo $(pwd)
echo $FPM_CMD
eval $FPM_CMD

cd ..
rm build/*.deb || echo "no deb packages in build/*.deb"
mkdir build || echo "build directory already created"
mv tmp/*.deb build/.

echo "cleaning up"

#echo "Removing old package from gemfury"
#set +e  # in case package does not already exist
#gemfury yank $APP_NAME --version=$VERSION --as=chartboost
#set -e

#echo "Pushing new package to gemfury"
#gemfury push build/*.deb --as=chartboost

echo "Pushing new package to S3"
deb-s3 upload build/*.deb --bucket=cb-devops-debs -e -v private
