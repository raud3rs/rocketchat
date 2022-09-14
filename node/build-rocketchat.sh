#!/bin/bash -ex

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
BUILD_DIR=${DIR}

apt update
apt -y install patch libglib2.0-0 python build-essential pkg-config glib2.0-dev libexpat1-dev libtool autoconf g++ build-essential cmake

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh  -s -- -y
source "$HOME/.cargo/env"

#libvips-dev
#cd $BUILD_DIR
#cd vips-*
#./configure
#make
#make install

#rm -rf
#cp /usr/local/lib/libvips*.so* $BUILD_DIR/nodejs/usr/lib/*-linux-gnu*/
#ls -la $BUILD_DIR/nodejs/usr/lib/*-linux-gnu*/

cd ${DIR}
cd bundle
for f in ${DIR}/patches/*.patch
do
  patch -p0 < $f
done

#ls -la ${BUILD_DIR}
#ls -la ${BUILD_DIR}/bundle
#chown -R $(whoami). ${BUILD_DIR}/bundle
#ls -la ${BUILD_DIR}/bundle
#cat ${BUILD_DIR}/bundle/README
#ls -la ${BUILD_DIR}/bundle/programs
#ls -la ${BUILD_DIR}/bundle/programs/server
#export USER=$(whoami)

cd programs/server
CXX=g++-4.8 
CC=gcc-4.8
npm install --unsafe-perm --production

yes | rustup self uninstall
apt -y remove patch libglib2.0-0 python build-essential pkg-config glib2.0-dev libexpat1-dev libtool autoconf g++ build-essential cmake
apt -y autoclean
apt -y autoremove
rm -rf npm/node_modules/@rocket.chat/forked-matrix-sdk-crypto-nodejs/target
