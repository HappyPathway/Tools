#!/usr/bin/env bash

echo "This is the latest!"

export BUILD_VERSION=$(cat $TRAVIS_BUILD_DIR/build/package.json | jq -r .version)
export BINTRAY_PACKAGE=$(cat $TRAVIS_BUILD_DIR/build/package.json | jq -r .bintray_package)
export BINTRAY_REPO=$(cat $TRAVIS_BUILD_DIR/build/package.json | jq -r .bintray_repo)
export DEBIAN_PACKAGE="spinnaker-deployment-tools_${BUILD_VERSION}_amd64.deb"
export DEBIAN_ARCH=$(cat $TRAVIS_BUILD_DIR/build/package.json | jq -r .arch)
export DEBIAN_DISTRO=$(cat $TRAVIS_BUILD_DIR/build/package.json | jq -r .distro)
export DEBIAN_COMP=$(cat $TRAVIS_BUILD_DIR/build/package.json | jq -r .component)
export PACKAGE_PATH=$TRAVIS_BUILD_DIR/$1;

echo $DEBIAN_PACKAGE

fpm -s dir -t deb -n spinnaker-deployment-tools -v $BUILD_VERSION -a amd64 scripts/=/opt/spinnaker/tools/

if $(echo "${OSTYPE}" | grep -q darwin); then
    brew install awscli
else
    sudo apt-get install awscli
fi

pip install --upgrade --user awscli

aws s3 cp spinnaker-deployment-tools*.deb s3://cb-devops-repo/ 