FROM postgres:11.9

RUN apt-get update && apt-get -y upgrade

RUN apt-get install -y \
  sudo \
  make \
  postgresql-plperl-11 \
  libdbi-perl libdbd-pg-perl \
  libboolean-perl \
  wget \
  build-essential \
  libreadline-dev \
  libz-dev \
  autoconf \
  bison \
  libtool \
  libgeos-c1v5 \
  libproj-dev \
  libgdal-dev \
  libxml2-dev \
  libxml2-utils \
  xsltproc \
  docbook-xsl \
  docbook-mathml \
  libossp-uuid-dev \
  libperl-dev \
  libdbix-safe-perl