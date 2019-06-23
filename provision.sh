#!/bin/sh

if [ -n "$2" ]
then
	cat >> /etc/hosts <<-EOF
	$1 bfserver
	$2 pgwebserver
	EOF
fi

# box should be already provisioned with required packages

equivs-build /vagrant/pginfra-wrap-buildfarm
dpkg -i pginfra-wrap-buildfarm_1_all.deb

useradd -m -c "buildfarm owner" -s /bin/bash pgbuildfarm

cat >> /home/pgbuildfarm/.bashrc <<EOF
export PAGER=less
export LESS=-iMx4
export PGUSER=pgbuildfarm
export PGDATABASE=pgbfprod
EOF

usermod -a -G pgbuildfarm www-data

# If the directory exists, it's been cloned outside the VM, so link it in.
# Otherwise clone it here. If linking it, some of the chown/chmod
# commands might fail, but linking makes it possible to edit outside the VM
if [ -d /vagrant/website ]
then
	ln -s /vagrant/website /home/pgbuildfarm
else
	su -l pgbuildfarm -c "git clone https://github.com/PGBuildFarm/server-code.git website"
fi

su -l pgbuildfarm -c "cd website && make syncheck" || exit

mkdir /home/pgblocal
chown pgbuildfarm:www-data /home/pgblocal

su -l pgbuildfarm -c "git clone -q --bare https://git.postgresql.org/git/postgresql.git /home/pgblocal/postgresql.git"

mkdir /home/pgbuildfarm/website/buildlogs
mkdir /home/pgbuildfarm/website/weblogs
chown pgbuildfarm:pgbuildfarm  /home/pgbuildfarm/website/buildlogs
chown pgbuildfarm:www-data  /home/pgbuildfarm/website/weblogs
chmod g+w /home/pgbuildfarm/website/weblogs /home/pgbuildfarm/website/buildlogs

ls -l /home/pgbuildfarm/website


# what's on the actual server

: <<'EOF'

                                 List of roles
  Role name  |            Attributes             |          Member of          
-------------+-----------------------------------+-----------------------------
 admin       | No inheritance, Cannot login      | {postgres}
 adunstan    |                                   | {pgbfweb,pgbuildfarm}
 bfarchive   |                                   | {reader}
 pgbfweb     |                                   | {}
 pgbuildfarm |                                   | {}
 postgres    | Superuser, Create role, Create DB | {}
 radmin      |                                   | {}
 reader      |                                   | {}
 rssfeed     |                                   | {}
 sfrost      |                                   | {pgbfweb,pgbuildfarm,admin}

EOF

DBPW=`openssl rand -hex 12`

# use generic roles for sysadmin, dba - these would normally be real users

cat > /tmp/roles.sql <<EOF

create user pgbuildfarm;
create user pgbfweb password '$DBPW';
create user reader;
create role admin;
create user bfarchive;
create user dba;
create user sysadm;
grant reader to bfarchive;
grant postgres to admin;
grant pgbfweb, pgbuildfarm to dba, sysadm;
grant admin to sysadm;
create user radmin;
create user rssfeed;

EOF


su -l postgres -c "psql -f /tmp/roles.sql"

su -l postgres -c "createdb -O pgbuildfarm -T template0 -E SQL_ASCII pgbfprod"

su -l postgres -c "psql -f /home/pgbuildfarm/website/schema/bfwebdb.sql pgbfprod"

cat >> /home/pgbuildfarm/website/BuildFarmWeb.pl <<'EOF'

$ENV{BF_DEBUG} = 1;
$ENV{MAILADDRESS} = 'pgbuildfarm@brentalia.postgresql.org';
use vars 
    qw(
       $dbhost $dbname $dbuser $dbpass $dbport
       $notifyapp
       $all_stat $fail_stat $change_stat $green_stat
       $captcha_pubkey $captcha_privkey
       $captcha_invis_pubkey $captcha_invis_privkey
       $template_dir
       $default_host
       $local_git_clone
       $status_from $register_from $reminders_from $alerts_from
       $status_url
       $skip_mail
	   $skip_rss
	   $skip_captcha
	   $ignore_branches_of_interest
       );


$skip_mail = 1;
$skip_rss = 1;
$skip_captcha = 1;
$ignore_branches_of_interest = 1;


$status_url = undef; # 'https://buildfarm.postgresql.org';

$template_dir = '/home/pgbuildfarm/website/templates';

$default_host = undef; # 'brentalia.postgresql.org';

#$dbhost = "www.pgbuildfarm.org"; # undef = Unix Socket or libpq default
$dbhost = undef;
$dbname = "pgbfprod";
$dbuser = "pgbfweb";
$dbpass = "FILLMEIN";
$dbport = undef; # 5437; # undef = default

# addresses to email about new applications
#$notifyapp=[qw( adunstan@postgresql.org )];
# $notifyapp=[qw( buildfarm-admins@postgresql.org )];

# from addresses for various mailings
# $alerts_from = 'buildfarm-admins@postgresql.org';
# $status_from = 'buildfarm-admins@postgresql.org';
# $register_from = 'sysadmin-reports@postgresql.org';
# $reminders_from = 'sysadmin-reports@postgresql.org';

# addresses for mailing lists for status notifications

#$all_stat=['pgbuildfarm-status-all@pgfoundry.org'];
#$fail_stat=['pgbuildfarm-status-fail@pgfoundry.org','buildfarm-status-failures@postgresql.org'];
#$change_stat=['pgbuildfarm-status-chngs@pgfoundry.org'];
#$green_stat=['pgbuildfarm-status-green@pgfoundry.org','buildfarm-status-green-chgs@postgresql.org'];

$all_stat=[];
$fail_stat=['buildfarm-status-failures@postgresql.org'];
$change_stat=[];
$green_stat=['buildfarm-status-green-chgs@postgresql.org'];

# minimum acceptable script versions

$min_script_version = "1.108";
$min_web_script_version = "4.4";

# for invisible captchas v2 buildfarm.postgresql.org
$captcha_invis_pubkey = '';
$captcha_invis_privkey = '';

$local_git_clone = '/home/pgblocal/postgresql.git';

1;

EOF

sed -i -e "s/FILLMEIN/$DBPW/" /home/pgbuildfarm/website/BuildFarmWeb.pl
chown pgbuildfarm:pgbuildfarm /home/pgbuildfarm/website/BuildFarmWeb.pl


# a couple of things not run here in test env

crontab -u pgbuildfarm - <<'EOF'
# m h  dom mon dow   command
# crontab for buildfarm
#
PGDATABASE=pgbfprod
BFConfDir=/home/pgbuildfarm/website
#
#
# analyse the dashboard hourly
27 * * * * psql -q -c 'analyze dashboard_mat;'
#
# clean the recent history table
41 5 * * * psql -q -c 'select purge_build_status_recent_500();' > /dev/null
# remove log files older than 7 days
#
# run the alerts
#*/5 * * * * /home/pgbuildfarm/website/bin/bf-alerts.pl >> /home/pgbuildfarm/alertlogs/alert-log-`date +\%Y-\%m-\%d` 2>&1
#45 3 * * * find /home/pgbuildfarm/alertlogs/ -name 'alert-log*' -mtime +10 -exec /bin/rm {} \;

# Once a week, send out the mail of all pending requests.
#
#0 9 * * 1 /usr/bin/python /home/pgbuildfarm/website/bin/pgbf_mail.py
#0 9 * * 1 /home/pgbuildfarm/website/bin/applications_reminder.pl
# keep the git clone up to date
*/5 * * * * cd /home/pgbuildfarm/postgresql.git && git fetch -q
# END
EOF

crontab -u www-data - <<'EOF'

22 * * * * find /home/pgbuildfarm/website/buildlogs -depth -mmin +60 -type d -name tmp.\* -exec rm -rf {} \;
10 * * * * /home/pgbuildfarm/website/bin/cleanfiles.pl

EOF

cat >>/etc/cron.d/pg-analyze  <<'EOF'
# Analyze the database daily
41 4 * * * postgres psql -d pgbfprod -q -c 'analyze;'
EOF

cat > /etc/postgresql/11/main/pg_hba.conf <<'EOF'
# Database administrative login by Unix domain socket
local   all             postgres                                peer

# TYPE  DATABASE        USER            CIDR-ADDRESS            METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer map=peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256
# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256
EOF


# note use of generic sysadmin and dba ids.

cat > /etc/postgresql/11/main/pg_ident.conf <<'EOF'
peer www-data pgbfweb
peer dba pgbuildfarm
peer pgbuildfarm pgbuildfarm
peer sysadmin pgbuildfarm
peer root pgbuildfarm
peer /^(.*)$    \1
EOF

systemctl reload postgresql


cat > /etc/lighttpd/conf-enabled/buildfarm.conf <<'EOF'

server.modules += ( "mod_status", "mod_accesslog", "mod_setenv", "mod_cgi", "mod_rewrite")

 
$HTTP["scheme"] =~ "https?" {
   server.document-root = "/home/pgbuildfarm/website/htdocs"
   accesslog.filename = "/home/pgbuildfarm/website/weblogs/lightty-access.log"
   server.breakagelog = "/home/pgbuildfarm/website/weblogs/lightty-breakage.log"

   url.rewrite-once = ( "^/latest(/.*)?$" => "/cgi-bin/latest.pl$1" )

   $HTTP["url"] =~ "^/cgi-bin/" {
      setenv.add-environment = ( "BFConfDir" => "/home/pgbuildfarm/website", "BF_DEBUG" => "on" )
      cgi.assign = ( ".pl" => "/usr/bin/perl" )
      alias.url = (
         "/cgi-bin/" => "/home/pgbuildfarm/website/cgi-bin/",
      )
   }

   $HTTP["url"] =~ "^/downloads/" {
      dir-listing.activate = "enable"
   }

# omit https redirect

}

EOF

systemctl restart lighttpd

su - pgbuildfarm <<'EOF'

DIR=`mktemp -d`
cd $DIR
wget -nv https://buildfarm.postgresql.org/downloads/sample-data.tgz
tar -z -xf sample-data.tgz
psql -q -f load-sample-data.sql pgbfprod
cd
rm -rf $DIR

EOF
