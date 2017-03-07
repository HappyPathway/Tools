#!/usr/bin/env bash
export BUILD_VERSION=$(cat $TRAVIS_BUILD_DIR/build/package.json | jq -r .version)
export DEBIAN_PACKAGE="spinnaker-deployment-tools_${BUILD_VERSION}_amd64.deb"
echo $DEBIAN_PACKAGE

fpm -s dir -t deb -n spinnaker-deployment-tools -v $BUILD_VERSION scripts/=/opt/spinnaker/tools/

deb-s3 delete spinnaker-deployment-tools --versions=$BUILD_VERSION --arch amd64 --bucket=cb-devops-debs
deb-s3 upload --bucket cb-devops-debs "$DEBIAN_PACKAGE" -e -v private
