#!/bin/bash
#
# provision.sh
#
# This file is specified in Vagrantfile and is loaded by Vagrant as the primary
# provisioning script whenever the commands `vagrant up`, `vagrant provision`,
# or `vagrant reload` are used. It provides all of the default packages and
# configurations included with Varying Vagrant Vagrants.

# By storing the date now, we can calculate the duration of provisioning at the
# end of this script.
start_seconds="$(date +%s)"

# Capture a basic ping result to Google's primary DNS server to determine if
# outside access is available to us. If this does not reply after 2 attempts,
# we try one of Level3's DNS servers as well. If neither IP replies to a ping,
# then we'll skip a few things further in provisioning rather than creating a
# bunch of errors.
ping_result="$(ping -c 2 8.8.4.4 2>&1)"
if [[ $ping_result != *bytes?from* ]]; then
    ping_result="$(ping -c 2 4.2.2.2 2>&1)"
fi

# PACKAGE INSTALLATION
#
# Build a bash array to pass all of the packages we want to install to a single
# apt-get command. This avoids doing all the leg work each time a package is
# set to install. It also allows us to easily comment out or add single
# packages. We set the array as empty to begin with so that we can append
# individual packages to it as required.

#install base
apt-get install -y wget curl ca-certificates


apt_package_install_list=()

# Start with a bash array containing all packages we want to install in the
# virtual machine. We'll then loop through each of these and check individual
# status before adding them to the apt_package_install_list array.
apt_package_check_list=(

    # PHP5
    php5-fpm
    php5-cli

    # Common and dev packages for php
    php5-common
    php5-dev

    # Extra PHP modules that we find useful
    php5-memcache
    php5-imagick
    php5-mcrypt
    php5-imap
    php5-curl
    php-pear
    php5-gd
    php5-xdebug 
    php5-xhprof 
    php5-intl 
    php5-apcu
    libyaml-dev

    # nginx is installed as the default web server
    nginx-full

    # memcached is made available for object caching
    memcached

    # other packages that come in handy
    screen
    htop    
    imagemagick
    git-core
    zip
    unzip
    ngrep
    curl
    make
    vim
    colordiff
    imagemagick
    optipng
    jpegoptim
    rsync
    msmtp-mta
    openssl

    # Req'd for i18n tools
    gettext

    # Req'd for Webgrind
    graphviz

    # dos2unix
    # Allows conversion of DOS style line endings to something we'll have less
    # trouble with in Linux.
    dos2unix

    # nodejs for use by grunt
    #g++
    #npm
    #nodejs
)

echo "Check for apt packages to install..."

# Loop through each of our packages that should be installed on the system. If
# not yet installed, it should be added to the array of packages to install.
for pkg in "${apt_package_check_list[@]}"; do
    package_version="$(dpkg -s $pkg 2>&1 | grep 'Version:' | cut -d " " -f 2)"
    if [[ -n "${package_version}" ]]; then
        space_count="$(expr 20 - "${#pkg}")" #11
        pack_space_count="$(expr 30 - "${#package_version}")"
        real_space="$(expr ${space_count} + ${pack_space_count} + ${#package_version})"
        printf " * $pkg %${real_space}.${#package_version}s ${package_version}\n"
    else
        echo " *" $pkg [not installed]
        apt_package_install_list+=($pkg)
    fi
done

# There is a naming conflict with the node package (Amateur Packet Radio Node
# Program), and the nodejs binary has been renamed from node to nodejs. We need
# to symlink to put it back.
#ln -s /usr/bin/nodejs /usr/bin/node


# Provide our custom apt sources before running `apt-get update`
cp /srv/config/apt/sources.list.d/nginx.list /etc/apt/sources.list.d/nginx.list
cp /srv/config/apt/sources.list.d/dotdeb.list /etc/apt/sources.list.d/dotdeb.list

echo "Linked custom apt sources"

if [[ $ping_result == *bytes?from* ]]; then
    # If there are any packages to be installed in the apt_package_list array,
    # then we'll run `apt-get update` and then `apt-get install` to proceed.
    if [[ ${#apt_package_install_list[@]} = 0 ]]; then
        echo -e "No apt packages to install.\n"
    else
        # Before running `apt-get update`, we should add the public keys for
        # the packages that we are installing from non standard sources via
        # our appended apt source.list

        wget http://nginx.org/keys/nginx_signing.key
		apt-key add nginx_signing.key

		wget http://www.dotdeb.org/dotdeb.gpg
		apt-key add dotdeb.gpg

        # update all of the package references before installing anything
        echo "Running apt-get update..."
        apt-get update --assume-yes

        apt-get dist-upgrade --assume-yes

        # install required packages
        echo "Installing apt-get packages..."
        apt-get install --assume-yes ${apt_package_install_list[@]}

        # Clean up apt caches
        apt-get clean
    fi

    # xdebug
    pecl install yaml


    # ack-grep
    #
    # Install ack-rep directory from the version hosted at beyondgrep.com as the
    # PPAs for Ubuntu Precise are not available yet.
    if [[ -f /usr/bin/ack ]]; then
        echo "ack-grep already installed"
    else
        echo "Installing ack-grep as ack"
        curl -s http://beyondgrep.com/ack-2.04-single-file > /usr/bin/ack && chmod +x /usr/bin/ack
    fi

    # COMPOSER
    #
    # Install or Update Composer based on current state. Updates are direct from
    # master branch on GitHub repository.
    if [[ -n "$(composer --version | grep -q 'version')" ]]; then
        echo "Updating Composer..."
        composer self-update
    else
        echo "Installing Composer..."
        curl -sS https://getcomposer.org/installer | php
        chmod +x composer.phar
        mv composer.phar /usr/bin/composer
    fi
else
    echo -e "\nNo network connection available, skipping package installation"
fi

# Configuration for nginx

#get keys
if [[ ! -e /etc/nginx/server.key ]]; then
    echo "Generate Nginx server private key..."
    vvvgenrsa="$(openssl genrsa -out /etc/nginx/server.key 2048 2>&1)"
    echo $vvvgenrsa
fi
if [[ ! -e /etc/nginx/server.csr ]]; then
    echo "Generate Certificate Signing Request (CSR)..."
    openssl req -new -batch -key /etc/nginx/server.key -out /etc/nginx/server.csr
fi
if [[ ! -e /etc/nginx/server.crt ]]; then
    echo "Sign the certificate using the above private key and CSR..."
    vvvsigncert="$(openssl x509 -req -days 365 -in /etc/nginx/server.csr -signkey /etc/nginx/server.key -out /etc/nginx/server.crt 2>&1)"
    echo $vvvsigncert
fi

echo -e "\nSetup configuration files..."

# Copy nginx configuration from local

echo " * /srv/config/nginx-config/               -> /etc/nginx/"
rsync -vrlc /srv/config/nginx/ /etc/nginx/

# Copy php-fpm configuration from local
echo " * /srv/config/php5/               -> /etc/php5/"
rsync -vrlc /srv/config/php5/ /etc/php5/

# Copy memcached configuration from local
cp /srv/config/memcached/memcached.conf /etc/memcached.conf
echo " * /srv/config/memcached/memcached.conf   -> /etc/memcached.conf"

mkdir -p /var/www/default
chown -R root:www-data /var/www/default

# RESTART SERVICES
#
# Make sure the services we expect to be running are running.
echo -e "\nRestart services..."
service nginx restart
service memcached restart
service php5-fpm restart

if [[ $ping_result == *bytes?from* ]]; then  
    # Download and extract phpMemcachedAdmin to provide a dashboard view and
    # admin interface to the goings on of memcached when running
    if [[ ! -d /var/www/default/memcached-admin ]]; then
        echo -e "\nDownloading phpMemcachedAdmin, see https://code.google.com/p/phpmemcacheadmin/"
        cd /var/www/default
        wget -q -O phpmemcachedadmin.tar.gz 'https://phpmemcacheadmin.googlecode.com/files/phpMemcachedAdmin-1.2.2-r262.tar.gz'
        mkdir memcached-admin
        tar -xf phpmemcachedadmin.tar.gz --directory memcached-admin
        rm phpmemcachedadmin.tar.gz
    else
        echo "phpMemcachedAdmin already installed."
    fi

    # Checkout Opcache Status to provide a dashboard for viewing statistics
    # about PHP's built in opcache.
    if [[ ! -d /var/www/default/opcache-status ]]; then
        echo -e "\nDownloading Opcache Status, see https://github.com/rlerdorf/opcache-status/"
        cd /var/www/default
        git clone https://github.com/rlerdorf/opcache-status.git opcache-status
    else
        echo -e "\nUpdating Opcache Status"
        cd /var/www/default/opcache-status
        git pull --rebase origin master
    fi

    # Webgrind install (for viewing callgrind/cachegrind files produced by
    # xdebug profiler)
    if [[ ! -d /var/www/default/webgrind ]]; then
        echo -e "\nDownloading webgrind, see https://github.com/jokkedk/webgrind"
        git clone git://github.com/jokkedk/webgrind.git /srv/www/default/webgrind
    else
        echo -e "\nUpdating webgrind..."
        cd /var/www/default/webgrind
        git pull --rebase origin master
    fi    
else
    echo -e "\nNo network available, skipping network installations"
fi

# add domains to local host file


#enable nginx vhosts


# RESTART SERVICES AGAIN
#
# Make sure the services we expect to be running are running.
echo -e "\nRestart Nginx..."
service nginx restart

end_seconds="$(date +%s)"
echo "-----------------------------"
echo "Provisioning complete in "$(expr $end_seconds - $start_seconds)" seconds"
if [[ $ping_result == *bytes?from* ]]; then
    echo "External network connection established, packages up to date."
else
    echo "No external network available. Package installation and maintenance skipped."
fi
echo "Done ..."
