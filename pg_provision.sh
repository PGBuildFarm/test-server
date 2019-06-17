#!/bin/sh

if [ -n "$2" ]
then
	cat >> /etc/hosts <<-EOF
	$1 bfserver
	$2 pgwebserver
	EOF
fi

export DEBIAN_FRONTEND=noninteractive

echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" > /etc/apt/sources.list.d/pgdg.list
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=yes apt-key add -


apt-get update -y

apt-get install -y postgresql-11\
		postgresql-contrib-11 
# id
# pw

cat >> /etc/postgresql/11/main/conf.d/buildfarm.conf <<EOF
listen_addresses = '*'
password_encryption = 'scram-sha-256'
EOF

systemctl restart postgresql

# apt-get install -y emacs-nox
apt-get install -y vim git make
update-alternatives --set editor /usr/bin/vim.basic

apt-get install -y python3-pip python3-psycopg2

cd /opt

git clone https://git.postgresql.org/git/pgweb.git
cd pgweb
pip3 install -r requirements.txt

su - postgres -c 'createdb pgweb'

cat > pgweb/settings_local.py <<EOF
DEBUG=True
TEMPLATE_DEBUG=DEBUG
SITE_ROOT="http://localhost:8000"
SESSION_COOKIE_SECURE=False
SESSION_COOKIE_DOMAIN=None
EOF

su - postgres -c "cd /opt/pgweb && ./manage.py migrate"

