#!/bin/sh

if [ -e /etc/box_is_bfbase ]
then
	echo "base packages already installed"
	exit
fi

export DEBIAN_FRONTEND=noninteractive

apt-get install -y postgresql-common
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh

apt-get update -y

apt-get install -y postgresql-17\
		postgresql-contrib-17 \
		postgresql-plperl-17 \
		postgresql-17-dbgsym \
		postgresql-17-partman \
		postgresql-17-partman-dbgsym \
		lighttpd \
		zip unzip

cat >> /etc/postgresql/17/main/conf.d/buildfarm.conf <<EOF
listen_addresses = '*'
password_encryption = 'scram-sha-256'
EOF

systemctl restart postgresql

#apt-get install -y emacs-nox
apt-get install -y vim git make screen lsof
update-alternatives --set editor /usr/bin/vim.basic

# required for buildfarm server
apt-get install -y equivs libtemplate-perl libcgi-pm-perl libdbi-perl \
	libdbd-pg-perl libsoap-lite-perl libtime-parsedate-perl \
	libxml-rss-perl libcrypt-urandom-perl

# required for pgweb server
apt-get install -y python3-pip python3-psycopg2 python3-yaml

