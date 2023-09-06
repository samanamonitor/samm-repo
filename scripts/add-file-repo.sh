#!/bin/bash

set -xe

do_hash() {
    HASH_NAME=$1
    HASH_CMD=$2
    echo "${HASH_NAME}:"
    for f in $(find -type f); do
        f=$(echo $f | cut -c3-) # remove ./ prefix
        if [ "$f" = "Release" ]; then
            continue
        fi
        echo " $(${HASH_CMD} ${f}  | cut -d" " -f1) $(wc -c $f)"
    done
}

usage() {
    echo $1 >&2
    echo "Usage: $0 <debian package> <version codename>" >&2
    exit 1
}

PKG_FILE=$1
VERSION_CODENAME=$2
PACKAGE_ARCH=$3
VERSION_NUMBER=1.0.0

if [ -z "${PACKAGE_ARCH}" ]; then
    usage "Package architecture is mandatory"
fi
if [ -z "${PKG_FILE}" ] || [ -z "${VERSION_CODENAME}" ]; then
    usage "Invalid parameters."
fi
if [ ! -f ${PKG_FILE} ]; then
    usage "Package file not available"
fi
if [ ! -f pgp-key.private ]; then
    usage "To continue, download the private key to current directory"
fi

CURDIR=/usr/src
DISTS_DIR=dists/${VERSION_CODENAME}
PACKAGE_DIR=${DISTS_DIR}/main/binary-${PACKAGE_ARCH}
POOL_DIR=pool/main/${VERSION_CODENAME}
TEMPDIR=$(mktemp -d ${CURDIR}/repo-XXXXX)
mkdir -p ${CURDIR}/gpg

export GNUPGHOME="$(mktemp -d ${CURDIR}/gpg/pgpkeys-XXXXXX)"

cat pgp-key.private | gpg --import

mkdir -p ${TEMPDIR}/${PACKAGE_DIR}
mkdir -p ${TEMPDIR}/${POOL_DIR}
cp ${PKG_FILE} ${TEMPDIR}/${POOL_DIR}

cd ${TEMPDIR}
#aws s3 cp s3://samm-repo/${PACKAGE_DIR}/Packages ${PACKAGE_DIR}/
aws s3 cp  s3://samm-repo/dists dists --recursive
if [ ! -f ${PACKAGE_DIR}/Packages ]; then
    touch ${PACKAGE_DIR}/Packages
fi
PKG_NAME=$(dpkg-deb -f ${POOL_DIR}/${PKG_FILE} Package)
# Delete package info if it exists
sed -i "/^Package: ${PKG_NAME}$/,/^$/d" ${PACKAGE_DIR}/Packages
# Adds package info
dpkg-scanpackages ${POOL_DIR} >> ${PACKAGE_DIR}/Packages
cat ${PACKAGE_DIR}/Packages | gzip -9  > ${PACKAGE_DIR}/Packages.gz

cd ${DISTS_DIR}
cat << EOF > Release
Origin: Samana Monitor Repository
Label: SAMM
Suite: ${VERSION_CODENAME}
Codename: ${VERSION_CODENAME}
Version: ${VERSION_NUMBER}
Architectures: amd64 arm64
Components: main
Description: SAMM Samana Advanced Monitoring and Management repository
Date: $(date -Ru)
EOF
do_hash "MD5Sum" "md5sum" >> Release
do_hash "SHA1" "sha1sum" >> Release
do_hash "SHA256" "sha256sum" >> Release
cat Release | gpg --default-key SamanaMonitor -abs > Release.gpg
cat Release | gpg --default-key SamanaMonitor -abs --clearsign > InRelease
cd ${TEMPDIR}

# Upload all files to repo
aws s3 cp ${POOL_DIR}/${PKG_FILE} s3://samm-repo/${POOL_DIR}/ --acl public-read
aws s3 cp ${PACKAGE_DIR}/Packages s3://samm-repo/${PACKAGE_DIR}/ --acl public-read
aws s3 cp ${PACKAGE_DIR}/Packages.gz s3://samm-repo/${PACKAGE_DIR}/ --acl public-read
aws s3 cp ${DISTS_DIR}/Release s3://samm-repo/${DISTS_DIR}/ --acl public-read
aws s3 cp ${DISTS_DIR}/Release.gpg s3://samm-repo/${DISTS_DIR}/ --acl public-read
aws s3 cp ${DISTS_DIR}/InRelease s3://samm-repo/${DISTS_DIR}/ --acl public-read
# Cleanup
cd ${CURDIR}
rm -Rf ${TEMPDIR} ${CURDIR}/gpg
