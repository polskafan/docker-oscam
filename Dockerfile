# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-alpine:3.18

# set version label
ARG BUILD_DATE
ARG VERSION
ARG OSCAM_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="saarg"

COPY patches/ /patches

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    build-base \
    libusb-dev \
    linux-headers \
    openssl-dev \
    pcsc-lite-dev \
    subversion && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    ccid \
    libusb \
    pcsc-lite \
    pcsc-lite-libs && \
  echo "**** compile oscam ****" && \
  if [ -z ${OSCAM_VERSION+x} ]; then \
    OSCAM_VERSION=$(svn info --show-item revision https://svn.streamboard.tv/oscam/trunk ); \
  fi && \
  svn checkout https://svn.streamboard.tv/oscam/trunk@${OSCAM_VERSION} /tmp/oscam-svn && \
  cd /tmp/oscam-svn && \
  patch -i /patches/provid.patch && \
  ./config.sh \
    --enable all \
    --disable \
    CARDREADER_DB2COM \
    CARDREADER_INTERNAL \
    CARDREADER_STINGER \
    CARDREADER_STAPI \
    CARDREADER_STAPI5 \
    IPV6SUPPORT \
    LCDSUPPORT \
    LEDSUPPORT \
    READ_SDT_CHARSETS && \
  make \
    CONF_DIR=/config \
    DEFAULT_PCSC_FLAGS="-I/usr/include/PCSC" \
    NO_PLUS_TARGET=1 \
    OSCAM_BIN=/usr/bin/oscam \
    pcsc-libusb && \
  echo "**** fix broken permissions from pcscd install ****" && \
  chown root:root \
    /usr/sbin/pcscd && \
  chmod 755 \
    /usr/sbin/pcscd && \
  echo "**** install PCSC drivers from Linuxserver S3 due to Cloudflare blocking curl download from source (original file at https://www3.hidglobal.com/sites/default/files/drivers/ifdokccid_linux_x86_64-v4.2.8.tar.gz) ****" && \
  mkdir -p \
    /tmp/omnikey && \
  curl -o \
    /tmp/omnikey.tar.gz -L \
    "https://ci-tests.linuxserver.io/artifacts/ifdokccid_linux_x86_64-v4.2.8.tar.gz" && \
  tar xzf \
    /tmp/omnikey.tar.gz -C \
    /tmp/omnikey --strip-components=2 && \
  cd /tmp/omnikey && \
  ./install && \
  echo "**** fix group for card readers and add abc to dialout group ****" && \
  groupmod -g 24 cron && \
  groupmod -g 16 dialout && \
  usermod -a -G 16 abc && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/*

# copy local files
COPY root/ /

# Ports and volumes
EXPOSE 8888

VOLUME /config
