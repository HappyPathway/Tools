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

fpm -s dir -t deb -n spinnaker-deployment-tools -v $BUILD_VERSION scripts/=/opt/spinnaker/tools/

#deb-s3 delete spinnaker-deployment-tools --versions=$BUILD_VERSION --arch amd64 --bucket=cb-devops-debs
#deb-s3 upload --bucket cb-devops-debs "$DEBIAN_PACKAGE" -e -v private

echo $TRAVIS_BUILD_DIR/scripts/jfrog bt ps $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE

PKG_EXISTS=$($TRAVIS_BUILD_DIR/scripts/jfrog bt ps $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE | grep -q $BINTRAY_REPO; echo $?)
if [ $PKG_EXISTS != 0 ]
then
	echo $TRAVIS_BUILD_DIR/scripts/jfrog bt pc $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE
	$TRAVIS_BUILD_DIR/scripts/jfrog bt pc $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE
fi

echo $TRAVIS_BUILD_DIR/scripts/jfrog bt u --publish --deb=$DEBIAN_DISTRO/$DEBIAN_COMP/$DEBIAN_ARCH $DEBIAN_PACKAGE $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE/$BUILD_VERSION
$TRAVIS_BUILD_DIR/scripts/jfrog bt u --publish --deb=$DEBIAN_DISTRO/$DEBIAN_COMP/$DEBIAN_ARCH $DEBIAN_PACKAGE $BINTRAY_USER/$BINTRAY_REPO/$BINTRAY_PACKAGE/$BUILD_VERSION
