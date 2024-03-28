#!/bin/bash

EXPECTED_SIGNATURE=$(wget -q -O - https://composer.github.io/installer.sig)
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE=$(php -r "echo hash_file('SHA384', 'composer-setup.php');")

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
then
    >&2 echo 'ERROR: Invalid installer signature'
    rm composer-setup.php
    exit 1
fi

/usr/bin/php composer-setup.php  --install-dir=$HOME/.bin/local/bin --filename=composer
/usr/bin/php -r "unlink('composer-setup.php');"

$HOME/.bin/local/bin/composer global require phpunit/phpunit
$HOME/.bin/local/bin/composer global require phpunit/dbunit
$HOME/.bin/local/bin/composer global require phing/phing
$HOME/.bin/local/bin/composer global require phpdocumentor/phpdocumentor
$HOME/.bin/local/bin/composer global require sebastian/phpcpd
$HOME/.bin/local/bin/composer global require phploc/phploc
$HOME/.bin/local/bin/composer global require phpmd/phpmd
$HOME/.bin/local/bin/composer global require squizlabs/php_codesniffer
$HOME/.bin/local/bin/composer global require vimeo/psalm
