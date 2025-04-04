#!/bin/bash

sudo dpkg -l | grep php | tee packages.txt
sudo a2disconf php8*
sudo a2disconf php8*
reload
install_php_packages
sudo chown patrick:patrick /var/log/boot.log
sudo systemctl -f apache2 remove
sudo systemctl disable apache2
sudo systemctl disable mysql
sudo service apache2 start && sudo service mysql start
sudo service mysql stop && sudo service apache2 stop
sudo service apache2 status


gh release --repo composer/composer download --pattern composer.phar
gh attestation verify --repo composer/composer composer.phar
mkdir -p ~/.bin/local/bin/
mv composer.phar ~/.bin/local/bin/composer
chmod +x ~/.bin/local/bin/composer
composer --version
