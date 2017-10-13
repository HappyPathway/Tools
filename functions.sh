function init_tmp {
  mkdir tmp
  cd tmp
}

function needs_download {
  _has_url=$(jq 'select(.repoUrl != null)' ${CONFIG_FILE} | wc -l | bc)
  if [ "${_has_url}" -ne 0 ]
    then
      echo 0
    else
      echo 1
  fi
}

function download_pkg {
  echo "Downloading $PACKAGE_URL"
  wget $PACKAGE_URL
}

function pre_extract_commands {
  actual_array_size=$( jq -r ".preExtractCommands | length " < $CONFIG_FILE )
  if [ $actual_array_size -ne 0 ]
    then
      useable_array_size=$(echo $actual_array_size-1 | bc)
      commands=""
      for i in $(seq 0 $useable_array_size);
        do
          eval_command=$(jq -r .preExtractCommands[$i] < $CONFIG_FILE)
          echo $eval_command
          eval $eval_command
        done
  fi
}

function is_zip {
  zipfile=$(echo $PACKAGE_NAME | grep -c ".zip$" >/dev/null 2>&1; echo $?)
  if [ "$zipfile" -eq 0 ]
    then
      echo 0
    else
      echo 1
  fi
}

function unpack {
  echo "Extracting package $PACKAGE_NAME"
  ar x $PACKAGE_NAME
  rm $PACKAGE_NAME
}

function extract_data {
  echo "Extracting data.tar.gz into tmp/data"
  mkdir data
  tar -xvf data.tar.gz -C data
}

function extract_control {
  echo "Extracting control.tar.gz into tmp/control"
  mkdir control
  tar -xvf control.tar.gz -C control
}

function unpack_zip {
  echo "Unpacking zipfile"
  mkdir zip_data
  unzip $PACKAGE_NAME -d zip_data
}

function pre_config_commands {
  actual_array_size=$( jq -r ".preConfigCommands | length " < $CONFIG_FILE )
  if [ $actual_array_size -ne 0 ]
    then
      useable_array_size=$(echo $actual_array_size-1 | bc)
      commands=""
      for i in $(seq 0 $useable_array_size);
        do
          eval_command=$(jq -r .preConfigCommands[$i] < $CONFIG_FILE)
          echo $eval_command
          eval $eval_command
        done
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
          mkdir -p zip_data/$destination;
          cp $(pwd)/../$file_source zip_data/$destination/.;
      fi
    done
}

function pre_install {
  rm preinst
  pre_install=$(cat $CONFIG_FILE | jq -r .pre_install)
  if [ -f "tmp/control/preinst" ]
  then
    cp tmp/control/preinst preinst
  fi
  if [ $pre_install != "null" ]
  then
    cp $pre_install preinst
  fi
}

function post_install {
  rm postinst
  post_install=$(cat $CONFIG_FILE | jq -r .post_install)
  if [ -f "tmp/control/postinst" ]
  then
    cp tmp/control/postinst postinst
  fi
  if [ $post_install != "null" ]
  then
    cp $post_install postinst
  fi
}



function post_remove {
  rm postremove
  post_remove=$(cat $CONFIG_FILE | jq -r .pre_install)
  if [ -f "tmp/control/postremove" ]
  then
    cp tmp/control/postremove postremove
  fi
  if [ $post_remove != "null" ]
  then
    cp $post_remove postremove
  fi
}

function upstart_script {
  upstart_script=$(cat $CONFIG_FILE | jq -r .upstart)
  rm $(basename "$upstart_script")
  if [ $upstart_script != "null" ]
  then
      cp $upstart_script $(basename "$upstart_script")
      echo $(basename "$upstart_script")
  fi
}

function pkg_pre_dependencies {
  config=$1
  app_name=$2
  actual_array_size=$( jq -r ".pre_dependencies | length " < $CONFIG_FILE )
  useable_array_size=$(echo $actual_array_size-1 | bc)
  dependecies_flags=""
  if [ $actual_array_size -ne 0 ]
    then
      for i in $(seq 0 $useable_array_size);
        do
          dependencies=$(jq -r .pre_dependencies[$i] < $CONFIG_FILE)
          dependecies_flags="$dependecies_flags  --deb-pre-depends $dependencies "
        done
      echo $dependecies_flags
  fi
}

function pkg_dependencies {
  config=$1
  app_name=$2
  actual_array_size=$( jq -r ".dependencies | length " < $CONFIG_FILE )
  useable_array_size=$(echo $actual_array_size-1 | bc)
  dependecies_flags=""
  if [ $actual_array_size -ne 0 ]
    then
      for i in $(seq 0 $useable_array_size);
        do
          dependencies=$(jq -r .dependencies[$i] < $CONFIG_FILE)
          dependecies_flags="$dependecies_flags  --depends $dependencies "
        done
      echo $dependecies_flags
  fi
}









# possibly safe to remove
# --- below this line ---
function pkg_exists {
    bucket=$1
    package=$2
    version=$3
    return $(deb-s3 show --bucket=$bucket $package $version amd64 >/dev/null 2>&1; echo $?)
}

function repo_url {
  echo $(cat $CONFIG_FILE | jq -r .repoUrl)
}

function package_name {
  echo $(cat $CONFIG_FILE | jq -r .packageName)
}

function version {
 echo $(cat $CONFIG_FILE | jq -r .version)
}

function has_configs {
  actual_array_size=$( jq -r ".configs | length " < $CONFIG_FILE )
  if [ $actual_array_size -ne 0 ]
  then
    echo 0
  else
    echo 1
  fi
}

function default_configs {
  d_configs=$( jq -r ".default_configs " < $CONFIG_FILE )
  if [ $d_configs == "true" ]
  then
    echo 0
  else
    echo 1
  fi
}
