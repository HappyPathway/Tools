#!/bin/bash
set -e

CONFIG_FILE=$(pwd)/$1
APP_NAME=$2


echo "Using $CONFIG_FILE to build $APP_NAME"

REPO_URL=$(cat $CONFIG_FILE | jq -r .repoUrl)
echo Repo: $REPO_URL

PACKAGE_NAME=$(cat $CONFIG_FILE | jq -r .$APP_NAME.packageName)
echo Package: $PACKAGE_NAME


VERSION=$(cat $CONFIG_FILE | jq -r .$APP_NAME.version)
echo Version: $VERSION

PACKAGE_URL=$REPO_URL-$APP_NAME/$PACKAGE_NAME
echo Package url: $PACKAGE_URL

config_postinst=$(cat $CONFIG_FILE | jq -r .$APP_NAME.postinst)
if [ "$config_postinst" == "null" ]
then
  POST_INSTALL=default_postinst.sh
else
  POST_INSTALL=$config_postinst
fi
echo postinst: $POST_INSTALL

function get_source {
  config=$1
  app_name=$2
  index=$3
  echo  $(jq -r .$APP_NAME.configs[$index].source < $CONFIG_FILE)
}

function get_destination {
  config=$1
  app_name=$2
  index=$3
  echo  $(jq -r .$APP_NAME.configs[$index].destination < $CONFIG_FILE)
}

function pkg_dependencies {
  config=$1
  app_name=$2
  actual_array_size=$( jq -r ".$APP_NAME.dependencies | length " < $CONFIG_FILE )
  useable_array_size=$(echo $actual_array_size-1 | bc)
  dependecies_flags=""
  for i in $(seq 0 $useable_array_size);
    do
      dependencies=$(jq -r .$APP_NAME.dependencies[$i] < $CONFIG_FILE)
      dependecies_flags="$dependecies_flags  --depends $dependencies "
    done
  echo $dependecies_flags
}

function cp_configs {
  config=$1
  app_name=$2
  actual_array_size=$( jq -r ".$APP_NAME.configs | length " < $CONFIG_FILE )
  useable_array_size=$(echo $actual_array_size-1 | bc)
  for i in $(seq 0 $useable_array_size);
    do
      file_source=$(get_source $config $APP_NAME $i);
      destination=$(get_destination $config $APP_NAME $i)
      echo "$file_source -> $destination";
      mkdir -p data/$destination;
      cp $(pwd)/../$file_source data/$destination/.;
    done
}

function has_configs {
  actual_array_size=$( jq -r ".$APP_NAME.configs | length " < $CONFIG_FILE )
  if [ $actual_array_size -ne 0 ]
  then
    echo 0
  else
    echo 1
  fi
}

mkdir tmp
cd tmp
echo "Downloading package from $PACKAGE_URL"
wget $PACKAGE_URL

echo "Extracting package"
ar x $PACKAGE_NAME
rm $PACKAGE_NAME

echo "Extracting data.tar.gz into tmp/data"
mkdir data
tar -xvf data.tar.gz -C data

echo "Extracting control.tar.gz into tmp/control"
mkdir control
tar -xvf control.tar.gz -C control


has_configs=$( jq -r ".$APP_NAME.configs | length " < $CONFIG_FILE )
echo "This app has configs: $has_configs"
if [ $( jq -r ".$APP_NAME.configs | length " < $CONFIG_FILE ) -ne 0 ]
  then
    cp_configs $CONFIG_FILE $APP_NAME
fi

if [ $( jq -r ".$APP_NAME.default_configs " < $CONFIG_FILE ) == "true" ]
  then
    echo "Inserting $APP_NAME-local.yml, spinnaker-local.yml in opt/spinnaker/"
    cp $(pwd)/../$APP_NAME-local.yml data/opt/$APP_NAME/config/.
    cp $(pwd)/../spinnaker-local.yml data/opt/$APP_NAME/config/.
fi


echo "repacking debian package"
cd ..
FPM_CMD="fpm -s dir -t deb -n spinnaker-$APP_NAME -v $VERSION \
  --before-install tmp/control/preinst \
  --after-install $POST_INSTALL \
  --after-remove tmp/control/prerm \
  --after-remove tmp/control/postrm \
  $(pkg_dependencies $CONFIG_FILE $APP_NAME) \
  tmp/data/=/"

echo $FPM_CMD
eval $FPM_CMD

mv *.deb build/.

echo "cleaning up"
rm -r tmp

echo "Removing old package from gemfury"
set +e  # in case package does not already exist
gemfury yank spinnaker-$APP_NAME --version=$VERSION --as=chartboost
set -e

echo "Pushing new package to gemfury"
gemfury push build/*.deb --as=chartboost

echo "touching datadog package for Spinnaker to pick up"
touch build/$(jq -r ".packageName" < datadog/config.json)
