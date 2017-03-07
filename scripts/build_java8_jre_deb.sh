#!/bin/bash

# Download Oracle Java 8 JRE

wget --header "Cookie: oraclelicense=accept-securebackup-cookie" \
  http://download.oracle.com/otn-pub/java/jdk/8u5-b13/jdk-8u5-linux-x64.tar.gz
mkdir -p /tmp/jdk-8u5-linux-x64

tar -zxf jdk-8u5-linux-x64.tar.gz -C /tmp/jdk-8u5-linux-x64
rm jdk-8u5-linux-x64.tar.gz

echo "#!/bin/bash
mkdir -p /opt/jdk
" > /tmp/pre-install.sh

echo "#!/bin/bash
update-alternatives --install /usr/bin/java java /opt/jdk/jdk1.8.0_05/bin/java 100
update-alternatives --install /usr/bin/javac javac /opt/jdk/jdk1.8.0_05/bin/javac 100
" > /tmp/post-install.sh

fpm -s dir -t deb -n java-8-jre -v 1.8 \
  --before-install /tmp/pre-install.sh \
  --after-install  /tmp/post-install.sh \
  /tmp/jdk-8u5-linux-x64/=/opt/jdk/

rm build/java-8-jre_1.8_amd64.deb
mv java-8-jre_1.8_amd64.deb build/java-8-jre_1.8_amd64.deb

echo "Removing old package from gemfury"
set +e  # in case package does not already exist
gemfury yank java-8-jre --version=1.8 --as=chartboost
set -e

echo "Pushing new package to gemfury"
gemfury push build/java-8-jre_1.8_amd64.deb --as=chartboost

echo "cleaning up"
rm /tmp/pre-install.sh
rm /tmp/post-install.sh
rm -rf /tmp/jdk-8u5-linux-x64/
