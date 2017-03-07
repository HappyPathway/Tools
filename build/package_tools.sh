#!/usr/bin/env bash

brew install gnu-tar
brew install jq
gem install deb-s3 fpm

export BUILD_VERSION=$(cat package.json | jq -r .version)
export DEBIAN_PACKAGE="exchange-admin_${BUILD_VERSION}_amd64.deb"
echo $DEBIAN_PACKAGE

fpm -s dir -t deb -n exchange-admin -v $BUILD_VERSION \
	--before-install=./config/pre_install.sh \
	--after-install=./config/post_install.sh \
	--deb-pre-depends=nginx  \
	build/=/opt/chartboost/applications/exchange-admin config/nginx/=/etc/nginx/sites-enabled

deb-s3 delete exchange-admin --versions=$BUILD_VERSION --arch amd64 --bucket=cb-devops-debs
deb-s3 upload --bucket cb-devops-debs "$DEBIAN_PACKAGE" -e -v private
