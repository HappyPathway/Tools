#!/usr/bin/env bash
#!/bin/bash

base_dir=$(dirname $0)

if $(echo "${OSTYPE}" | grep -q darwin); then
    brew install awscli
else
    sudo apt-get install awscli
fi

pip install --upgrade --user awscli

export PACKAGE_PATH=$TRAVIS_BUILD_DIR/$1;
echo $PACKAGE_PATH

export REPO_BUCKET=$2;
echo $REPO_BUCKET;

aws s3 cp $PACKAGE_PATH s3://$REPO_BUCKET/ 