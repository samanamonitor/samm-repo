FROM ubuntu:jammy
ENV DEBIAN_FRONTEND="noninteractive"
RUN <<EOF
apt update
apt upgrade -y
apt install -y dpkg-dev awscli python3-setuptools
mkdir -p /root/.aws
chmod 700 /root/.aws
EOF
COPY credentials /root/.aws
COPY scripts/add-file-repo.sh scripts/build-deb.sh /usr/local/bin
WORKDIR /usr/src
