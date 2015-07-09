#!/bin/bash

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install LEMP"
    exit 1
fi

clear
echo "==========================================================="
echo "LEMP web stack v1.0 for Linux Ubuntu, written by GP"
echo "==========================================================="
echo "A tool to auto-compile & install Nginx+MySQL+PHP on Linux "
echo ""
echo "For more information please visit http://makewebfast.net"
echo "==========================================================="

# Dummy Credentials
FTP_USERNAME=makewebfast
FTP_GROUP=makewebfast
FTP_USER_PASSWORD=makewebfast
MYSQL_ROOT_PASSWORD=makewebfast

mkdir -p /var/www/html

sudo groupadd $FTP_GROUP
useradd -g $FTP_GROUP $FTP_USERNAME

echo "$FTP_USERNAME:$FTP_USER_PASSWORD" | chpasswd

# Limit FTP access only to /public_html directory
usermod --home /var/www/html $FTP_USERNAME
usermod -s /bin/bash $FTP_USERNAME

chown -R ${FTP_USERNAME}:${FTP_GROUP} /var/www/html
chmod 775 /var/www/html

# Create PHP session pool
mkdir -p /var/lib/php5/session
chown -R ${FTP_USERNAME}:${FTP_GROUP} /var/lib/php5/session
chmod 775 /var/lib/php5/session

##############
# Update distro #
##############

clear
echo "========================"
echo "Updating Ubuntu System"
echo "========================"
sudo apt-get update && sudo apt-get -y upgrade && sudo apt-get dist-upgrade 

##############################
# Add the necessary dependencies #
##############################
sudo apt-get install -y wget zip unzip

#################################################################################################
# Install NGINX - build it from source with all necessary modules - always check for updates here: http://goo.gl/B5PteX #
#################################################################################################

# Install dependencies
sudo apt-get install -y build-essential zlib1g-dev libpcre3 libpcre3-dev unzip libssl-dev libgd2-xpm-dev

# Download ngx_pagespeed
cd
NPS_VERSION=1.9.32.4
wget https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip
unzip release-${NPS_VERSION}-beta.zip
cd ngx_pagespeed-release-${NPS_VERSION}-beta/
wget https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz
tar -xzvf ${NPS_VERSION}.tar.gz

# Download and build nginx with all the necessary modules - check http://nginx.org/en/download.html for the latest version
cd
NGINX_VERSION=1.8.0
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -xvzf nginx-${NGINX_VERSION}.tar.gz
cd nginx-${NGINX_VERSION}/
./configure --add-module=$HOME/ngx_pagespeed-release-${NPS_VERSION}-beta --with-http_gzip_static_module --with-http_realip_module --with-http_ssl_module
make
make install

# Create / replace the Nginx configuration files
touch /usr/local/nginx/conf/nginx.conf
touch /usr/local/nginx/conf/makewebfast.net.conf
touch /etc/init.d/nginx

wget https://raw.githubusercontent.com/gabrielPav/ubuntu-lemp/master/conf/nginx/nginx.conf -O /usr/local/nginx/conf/nginx.conf
wget https://raw.githubusercontent.com/gabrielPav/ubuntu-lemp/master/conf/nginx/makewebfast.net.conf -O /usr/local/nginx/conf/makewebfast.net.conf
wget https://raw.githubusercontent.com/gabrielPav/ubuntu-lemp/master/conf/nginx/nginx.init.txt -O /etc/init.d/nginx

chmod +x /etc/init.d/nginx
sudo update-rc.d nginx defaults

service nginx start
sudo /etc/init.d/nginx status
sudo /etc/init.d/nginx configtest
sleep 10
service nginx stop
cd

###############################################
# install PHP-FPM with latest PHP 5.5 version #
###############################################

# PPA Repo for PHP 5.5 (Ubuntu 14.04 and later)
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:ondrej/php5
sudo apt-get update && sudo apt-get -y upgrade

sudo apt-get install -y php5-fpm php5-common php5-cli php5-cgi php5-dev php5-xmlrpc php5-curl php5-gd php5-xsl php5-imap php5-mysql php5-odbc php5-mcrypt php5-tidy php5-ldap php-pear php5-intl php5-pspell php5-readline php5-recode php5-sqlite php5-apcu php5-imagick php5-memcached php5-memcache

# Install and configure Zend Opcache (optional)
sudo pecl install zendopcache-7.0.4

cat <<EOT >> /etc/php5/mods-available/opcache.ini
opcache.enable=1
opcache.enable_cli=0
opcache.fast_shutdown=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=8000
opcache.revalidate_freq=60
EOT

sudo update-rc.d php5-fpm defaults

service php5-fpm start
service php5-fpm stop

# Change the user/group of PHP-FPM processes
sed -i 's/user = www-data/user = makewebfast/g' /etc/php5/fpm/pool.d/www.conf
sed -i 's/group = www-data/group = makewebfast/g' /etc/php5/fpm/pool.d/www.conf
sed -i 's/listen.owner = www-data/;listen.owner = www-data/g' /etc/php5/fpm/pool.d/www.conf
sed -i 's/listen.group = www-data/;listen.group = www-data/g' /etc/php5/fpm/pool.d/www.conf
sed -i 's/listen = \/var\/run\/php5-fpm.sock/listen = 127.0.0.1:9000/g' /etc/php5/fpm/pool.d/www.conf

# Change some PHP variables
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/fpm/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 90/g' /etc/php5/fpm/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php5/fpm/php.ini
sed -i 's/display_errors = On/display_errors = Off/g' /etc/php5/fpm/php.ini
sed -i 's/;session.save_path = "\/var\/lib\/php5\/sessions"/session.save_path = "\/var\/lib\/php5\/session"/g' /etc/php5/fpm/php.ini

sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/cli/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 90/g' /etc/php5/cli/php.ini
sed -i 's/memory_limit = -1/memory_limit = 512M/g' /etc/php5/cli/php.ini
sed -i 's/display_errors = On/display_errors = Off/g' /etc/php5/cli/php.ini
sed -i 's/;session.save_path = "\/var\/lib\/php5\/sessions"/session.save_path = "\/var\/lib\/php5\/session"/g' /etc/php5/cli/php.ini

sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' /etc/php5/cgi/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 90/g' /etc/php5/cgi/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 512M/g' /etc/php5/cgi/php.ini
sed -i 's/display_errors = On/display_errors = Off/g' /etc/php5/cgi/php.ini
sed -i 's/;session.save_path = "\/var\/lib\/php5\/sessions"/session.save_path = "\/var\/lib\/php5\/session"/g' /etc/php5/cgi/php.ini

sleep 5

#####################
# install MySQL 5.6 #
#####################

sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD'
sudo apt-get -y install mysql-server-5.6

sudo update-rc.d mysql defaults

sudo service mysql start
sleep 5
sudo service mysql stop


###################
# Install MySQLTuner #
###################
cd
wget --no-check-certificate https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
chmod +x mysqltuner.pl

###########################
# Install and configure VSFTPD #
###########################

# Install VSFTPD
sudo apt-get -y install vsftpd
service vsftpd start

# Configure VSFTPD
sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/g' /etc/vsftpd.conf
sed -i 's/#chown_uploads=YES/allow_writeable_chroot=YES/g' /etc/vsftpd.conf
sed -i 's/#write_enable=YES/write_enable=YES/g' /etc/vsftpd.conf
sed -i 's/#local_umask=022/local_umask=022/g' /etc/vsftpd.conf

service vsftpd stop
sleep 5

###################
# Restart key services #
###################
clear
echo "==============="
echo  "Start Nginx."
echo "==============="
service nginx start
echo "================="
echo  "Start PHP-FPM"
echo "================="
service php5-fpm start
echo "================="
echo  "Start vsFTPd"
echo "================="
service vsftpd start

cd

# Remove the installation files
rm -rf /root/nginx-1.8.0.tar.gz
rm -rf /root/nginx-1.8.0
rm -rf /root/release-1.9.32.4-beta.zip
rm -rf /root/ngx_pagespeed-release-1.9.32.4-beta

#####################
# Installation completed. #
#####################
clear
echo "========================================"
echo "LEMP Installation Complete!"
echo "========================================"
echo "The configuration is now ready for testing."
echo "========================================"
