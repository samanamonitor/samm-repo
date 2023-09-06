#!/bin/bash

set -xe

. /etc/os-release

TEMPDIR=/usr/src

if [ -f requirements.txt ]; then
    apt install -y python3-pip
    python3 -m pip install -r requirements.txt
fi

python3 setup.py build
python3 setup.py bdist

tarball_path=$(find dist -type f -name \*.tar.gz)
tarball=$(basename ${tarball_path})

t=${tarball%.linux-*.tar.gz}
VERSION=${t#*-}
PACKAGE_NAME=$(sed -n -e "s/^Package: \+//p" ${TEMPDIR}/debian/control)
PACKAGE_ARCH=$(sed -n -e "s/^Architecture: \+//p" ${TEMPDIR}/debian/control)

BUILD_DIR=${TEMPDIR}/${PACKAGE_NAME}_${VERSION}-1_${PACKAGE_ARCH}
mkdir -p ${BUILD_DIR}/DEBIAN
cp ${TEMPDIR}/debian/control ${BUILD_DIR}/DEBIAN
if [ -f ${TEMPDIR}/debian/postinst ]; then
    install -m 0755 -o root -g root ${TEMPDIR}/debian/postinst ${BUILD_DIR}/DEBIAN/postinst
fi

tar -C ${BUILD_DIR} -xzvf ${tarball_path}

dpkg --build ${BUILD_DIR}

python3 setup.py clean
rm -Rf build dist ${PACKAGE_NAME}_${VERSION}-1_${PACKAGE_ARCH} samm.egg-info
