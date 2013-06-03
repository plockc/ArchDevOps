#!/bin/bash

#
# USAGE: bash <(curl -fsSL https://raw.github.com/plockc/ArchDevOps/master/archInstall/dokuwikiInstall.sh)
#
# Will create a personal wiki (public to read but private to write)

# abort if there is an error
set -e

#####################
# INSTALL PACKAGES
#####################

pacman --noconfirm -S --needed php-apc php-cgi php-sqlite lighttpd dokuwiki

#####################
# CONFIGURE PHP CACHE
#####################

sed -ibak 's/;extension=apc.so/extension=apc.so/' /etc/php/conf.d/apc.ini # enable APC caching

####################
# CONFIGURE FASTCGI
####################

mkdir -p /etc/lighttpd/conf.d

# include fastcgi.conf
grep -q "conf.d/fastcgi.conf" /etc/lighttpd/lighttpd.conf \
   || (echo "include \"conf.d/fastcgi.conf\"" >> /etc/lighttpd/lighttpd.conf)

if ! test -f /etc/lighttpd/conf.d/fastcgi.conf; then
	cat > /etc/lighttpd/conf.d/fastcgi.conf << EOF
	server.modules += ( "mod_fastcgi" )
	index-file.names += ( "index.php" )
	fastcgi.server = ( ".php" =>
		 ( "localhost" =>
		 ("socket" => "/run/lighttpd/php-fastcgi.sock",
				"bin-path" => "/usr/bin/php-cgi",
				"max-procs" => 1,
	            "bin-environment" => ("PHP_FCGI_CHILDREN" => "1"),
				"broken-scriptfilename" => "enable"
						 )
					   )
					)
EOF
fi

####################
# CONFIGURE DOKUWIKI
####################

# configure PHP so it is authorized to access the wiki installation
sed -i 's#\(^open_base.*\)#\1:/etc/webapps/dokuwiki:/var/lib/dokuwiki#' /etc/php/php.ini

# include dokuwiki.conf
grep -q "conf.d/dokuwiki.conf" /etc/lighttpd/lighttpd.conf \
   || (echo "include \"conf.d/dokuwiki.conf\"" >> /etc/lighttpd/lighttpd.conf)

# create the dokuwiki configuration for lighttpd
test -f /etc/lighttpd/conf.d/dokuwiki.conf || cat > /etc/lighttpd/conf.d/dokuwiki.conf << EOF
server.modules += ( "mod_access", "mod_alias" )
alias.url += ("/wiki" => "/usr/share/webapps/dokuwiki/")
static-file.exclude-extensions = ( ".php" )
\$HTTP["url"] =~ "/(\.|_)ht" { url.access-deny = ( "" ) }
\$HTTP["url"] =~ "^/wiki/(bin|data|inc|conf)/+.*"  { url.access-deny = ( "" ) }
EOF

# create the dokuwiki local configuration if there is none
if test -f /usr/share/webapps/dokuwiki/conf/local.php; then
read -p "Enter a name for your Wiki: "
wikiTitle=$REPLY
read -p "Enter a tagline for your Wiki: "
wikiTagline=$REPLY
cp /usr/share/webapps/dokuwiki/conf/local.php  /usr/share/webapps/dokuwiki/conf/local.php.bak
cat > /usr/share/webapps/dokuwiki/conf/local.php << EOF
<?php
\$conf['title'] = "$wikiTitle";
\$conf['tagline'] = "$wikiTagLine;
\$conf['license'] = 'cc-by';
\$conf['breadcrumbs'] = 0;
\$conf['youarehere'] = 1;
\$conf['useheading'] = '1';
\$conf['useacl'] = 1;
\$conf['superuser'] = '@admin';
\$conf['disableactions'] = 'recent,revisions,register';
\$conf['htmlok'] = 1;
\$conf['userewrite'] = '2';
\$conf['plugin']['editx']['redirecttext'] = '~~REDIRECT>:@ID@~~ redirected to [[@ID@]]';
EOF


read -p "Dokuwiki Username: "
dokuUser=$REPLY
read -s -p "Dokuwiki Password: "
dokuPass=$REPLY
echo
read -s -p "Please confirm: "
echo

if [[ ! $REPLY == $dokuPass ]]
then
  echo && echo Passwords did not match, please try again
  exit;
fi

read -p "Dokuwiki User Full Name: "
dokuName=$REPLY
read -p "Dokuwiki email address: "
dokuEmail=$REPLY

echo "${dokuUser}:`openssl passwd -1 -stdin <<< $dokuPass`:$dokuName:$dokuEmail:admin,user" >> /usr/share/webapps/dokuwiki/conf/users.auth.php

cat >> /usr/share/webapps/dokuwiki/conf/acl.auth.php <<EOF
*               @ALL          1
*               @user         8
EOF

# download missing plugins
test -d /usr/share/webapps/dokuwiki/lib/plugins/editx \
  || (mkdir /usr/share/webapps/dokuwiki/lib/plugins/editx \
      && curl --location http://github.com/danny0838/dw-editx/tarball/release \
      | tar --strip-components=1 -zxC /usr/share/webapps/dokuwiki/lib/plugins/editx)
test -d /usr/share/webapps/dokuwiki/lib/plugins/pageredirect \
  || (mkdir /usr/share/webapps/dokuwiki/lib/plugins/pageredirect \
      && curl --location http://github.com/glensc/dokuwiki-plugin-pageredirect/tarball/master \
      | tar --strip-components=1 -zxC /usr/share/webapps/dokuwiki/lib/plugins/pageredirect)

chown -R http:http /usr/share/webapps/dokuwiki

chmod 744 /var/lib/dokuwiki

systemctl start lighttpd
