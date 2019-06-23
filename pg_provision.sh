#!/bin/sh

if [ -n "$2" ]
then
	BFIP=$1
	PGIP=$2
	cat >> /etc/hosts <<-EOF
	$BFIP bfserver
	$PGIP pgwebserver
	EOF
fi

# box should be already provisioned with required packages

cd /opt

git clone https://git.postgresql.org/git/pgweb.git
cd pgweb

sed -i s/psycopg2/psycopg2-binary/ requirements.txt

pip3 install -r requirements.txt

su - postgres -c 'createdb pgweb'

cat > pgweb/settings_local.py <<EOF
DEBUG=True
# TEMPLATE_DEBUG=DEBUG
SITE_ROOT="http://$PGIP:8000"
SESSION_COOKIE_SECURE=False
SESSION_COOKIE_DOMAIN=None
EOF

su - postgres -c "cd /opt/pgweb && ./manage.py migrate"

su - postgres -c "cd /opt/pgweb && psql -f sql/varnish.sql pgweb"

su - postgres -c "cd /opt/pgweb/pgweb && echo yes | ./load_initial_data.sh"

cat > /tmp/newusers.py <<EOF

from django.contrib.auth import get_user_model
get_user_model().objects.create_user(username='curly',
	email='curly@foo.com', password='curlycurlycurly')
get_user_model().objects.create_user(username='larry',
	email='larry@foo.com', password='larrylarrylarry')
get_user_model().objects.create_user(username='mo',
	email='mo@foo.com', password='momomo')
EOF

su - postgres -c "cd /opt/pgweb && ./manage.py shell < /tmp/newusers.py"

cat > /tmp/authsite.sql <<EOF
insert into public.account_communityauthorg values(default,'testbf',false);
insert into public.account_communityauthsite values(default,'testbf site', 'http://$BFIP/auth','x4dFBEISD6WL7Op8JNI/1xY0RUJSQM4ySbgquGwTvlQ=','foo bar',1,2);

EOF

su - postgres -c "psql -f /tmp/authsite.sql pgweb"

cat <<EOF
Now login to the machine and as user postgres do:

cd /opt/pgweb
./manage.py runserver 0.0.0.0:8000

This can also usefully be run in  screen session

EOF
