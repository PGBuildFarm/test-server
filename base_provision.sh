#!/bin/sh

if [ -e /etc/box_is_bfbase ]
then
	echo "base packages already installed"
	exit
fi

export DEBIAN_FRONTEND=noninteractive

echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=yes apt-key add -


apt-get update -y

apt-get install -y postgresql-11\
		postgresql-contrib-11 \
		postgresql-plperl-11 \
		postgresql-11-dbgsym \
		lighttpd \
		zip unzip

cat >> /etc/postgresql/11/main/conf.d/buildfarm.conf <<EOF
listen_addresses = '*'
password_encryption = 'scram-sha-256'
EOF

systemctl restart postgresql

#apt-get install -y emacs-nox
apt-get install -y vim git make screen lsof
update-alternatives --set editor /usr/bin/vim.basic

# required for buildfarm server
apt-get install -y equivs libtemplate-perl libcgi-pm-perl libdbi-perl \
		libdbd-pg-perl libsoap-lite-perl libtime-parsedate-perl libxml-rss-perl

# required for pgweb server
apt-get install -y python3-pip python3-psycopg2 python3-yaml

