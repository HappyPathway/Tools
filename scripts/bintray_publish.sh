#!/usr/bin/env bash

export PACKAGE_PATH=$TRAVIS_BUILD_DIR/$1;
export PACKAGE_CONFIG=$TRAVIS_BUILD_DIR/$2;

export BUILD_VERSION=$(cat $PACKAGE_CONFIG | jq -r .packageVersion)
export BINTRAY_PACKAGE=$(cat $PACKAGE_CONFIG | jq -r .bintray_package)
export BINTRAY_REPO=$(cat $PACKAGE_CONFIG | jq -r .bintray_repo)
export DEBIAN_PACKAGE="$BINTRAY_PACKAGE_${BUILD_VERSION}_amd64.deb"
export DEBIAN_ARCH=$(cat $PACKAGE_CONFIG | jq -r .arch)
export DEBIAN_DISTRO=$(cat $PACKAGE_CONFIG | jq -r .distro)
export DEBIAN_COMP=$(cat $PACKAGE_CONFIG | jq -r .component)

echo $DEBIAN_PACKAGE

echo $TRAVIS_BUILD_DIR/scripts/jfrog bt ps $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE

PKG_EXISTS=$($TRAVIS_BUILD_DIR/scripts/jfrog bt ps $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE | grep -q $BINTRAY_REPO; echo $?)
if [ $PKG_EXISTS != 0 ]
then
	echo $TRAVIS_BUILD_DIR/scripts/jfrog bt pc $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE
	$TRAVIS_BUILD_DIR/scripts/jfrog bt pc $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE
fi

$TRAVIS_BUILD_DIR/scripts/jfrog bt u  --deb=$DEBIAN_DISTRO/$DEBIAN_COMP/$DEBIAN_ARCH --publish=true --override=true $PACKAGE_PATH $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE/$BUILD_VERSION
