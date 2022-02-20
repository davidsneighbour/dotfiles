#!/bin/sh

FILE="/etc/apache2/sites-available/$1.conf"

sudo -u patrick

/bin/cat <<EOM >$FILE
<VirtualHost *:80>
	ServerName $1
	DocumentRoot /home/patrick/Projects/$2
	ErrorLog /home/patrick/Projects/LogFiles/$1-error.log
	CustomLog /home/patrick/Projects/LogFiles/$1-access.log combined
	<Directory /home/patrick/Projects/$2>
		Options All
		AllowOverride All
		Require local
	</Directory>
</VirtualHost>
<IfModule mod_ssl.c>
	<VirtualHost _default_:443>
		ServerName $1
		DocumentRoot /home/patrick/Projects/$2
		ErrorLog /home/patrick/Projects/LogFiles/$1-error.log
		CustomLog /home/patrick/Projects/LogFiles/$1-access.log combined
		<Directory /home/patrick/Projects/$2>
			Options All
			AllowOverride All
			Require local
		</Directory>
		SSLEngine on
		SSLCertificateFile	/etc/ssl/certs/ssl-cert-snakeoil.pem
		SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
		<FilesMatch "\.(cgi|shtml|phtml|php)$">
				SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
				SSLOptions +StdEnvVars
		</Directory>
	</VirtualHost>
</IfModule>
# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
EOM

sudo a2ensite $1.conf
sudo service apache2 restart

echo "Don't forget to add $1 to /etc/hosts."
