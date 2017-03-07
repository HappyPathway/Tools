#!/bin/bash
# Creates a debian package from the packer binary.
# Places the packer binary in /usr/local/packer
# Creates a symlink to put packer on the path: /usr/local/bin -> /usr/local/packer
wget https://releases.hashicorp.com/packer/0.11.0/packer_0.11.0_linux_amd64.zip
set +e

mkdir -p /tmp/packer/

tar -zxf packer_0.11.0_linux_amd64.zip -C /tmp/packer
rm packer_0.11.0_linux_amd64.zip

echo "#!/bin/bash
ln -s /usr/local/packer /usr/local/bin/packer
" > /tmp/post-install.sh

fpm -s dir -t deb -n packer -v 0.11.0 \
  --after-install  /tmp/post-install.sh \
  /tmp/packer/=/usr/local/

mv packer_0.11.0_amd64.deb build/packer_0.11.0_amd64.deb

echo "Removing old package from gemfury"
gemfury yank packer --version=0.11.0 --as=chartboost

echo "Pushing new package to gemfury"
gemfury push build/packer_0.11.0_amd64.deb --as=chartboost

echo "cleaning up"
rm /tmp/post-install.sh
rm -rf /tmp/packer/
